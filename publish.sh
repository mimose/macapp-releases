#!/usr/bin/env bash
# 把一个应用已打好的产物发布到 mimose/macapp-releases
#
# 用法：
#   ./publish.sh <应用源码目录> <版本号>
#   ./publish.sh ~/Coder/chenchangyu/textime 0.1.6
#
# 应用目录下需要 release.conf（bash 语法，可引用 $VERSION）：
#   APP=Textime                         # 展示名
#   SLUG=textime                        # tag 前缀，tag 为 <SLUG>/<版本号>
#   ASSETS=(dist/Textime-$VERSION.zip)  # 要上传的文件；以 ? 开头表示可选
#   NOTES_DIR=release-notes             # 可选：<版本>.zh.md / <版本>.en.md，每行「- 一条」
#   MAKE_LATEST=false                   # 可选：是否标记为仓库的 Latest release
#   SITE_DIR=site                       # 可选：官网目录，发布后写入固定下载地址与 appcast
#   PAGES_PROJECT=textime               # 可选：设置后用 wrangler 部署 SITE_DIR 到 Cloudflare Pages
#   SITE_GIT=true                       # 可选：官网由 git 推送自动部署时，提交并推送 SITE_DIR 的这两个文件
#
# 官网固定地址（SITE_DIR 生效时）：
#   /download/<APP>.<后缀>  302 到本次版本的 <APP>-<版本>.<后缀>（由 _redirects 生成）
#   /appcast.xml            本次的 appcast 副本，可作 Sparkle feed（国内访问 raw.githubusercontent 不稳定）
#
# 产物里有 appcast.xml 时，同时写到仓库 <SLUG>/appcast.xml，作为该应用固定的 Sparkle feed：
#   https://raw.githubusercontent.com/mimose/macapp-releases/master/<SLUG>/appcast.xml
#
# Token 依次取：GITHUB_TOKEN、<应用目录>/.cache/github_token、git credential（github.com）
set -euo pipefail

APP_ROOT="$(cd "${1:?用法: ./publish.sh <应用源码目录> <版本号>}" && pwd)"
VERSION="${2:?用法: ./publish.sh <应用源码目录> <版本号>}"
REPO="${RELEASE_REPO:-mimose/macapp-releases}"
BRANCH="${RELEASE_BRANCH:-master}"

CONF="$APP_ROOT/release.conf"
[ -f "$CONF" ] || { echo "✗ 缺少 $CONF"; exit 1; }
APP=""; SLUG=""; ASSETS=(); NOTES_DIR=""; MAKE_LATEST=false; SITE_DIR=""; PAGES_PROJECT=""; SITE_GIT=false
# shellcheck disable=SC1090
source "$CONF"
[ -n "$APP" ] && [ -n "$SLUG" ] && [ ${#ASSETS[@]} -gt 0 ] || { echo "✗ release.conf 需要 APP、SLUG、ASSETS"; exit 1; }
cd "$APP_ROOT"

TAG="$SLUG/$VERSION"

# ---------- 产物 ----------
FILES=()
for a in "${ASSETS[@]}"; do
  if [[ "$a" == \?* ]]; then
    [ -f "${a:1}" ] && FILES+=("${a:1}")
  else
    [ -f "$a" ] || { echo "✗ 缺少 ${APP_ROOT}/${a}（先打包）"; exit 1; }
    FILES+=("$a")
  fi
done
APPCAST=""
for f in "${FILES[@]}"; do [ "$(basename "$f")" = appcast.xml ] && APPCAST="$f"; done
if [ -n "$APPCAST" ]; then
  grep -q "<sparkle:shortVersionString>$VERSION<" "$APPCAST" || { echo "✗ $APPCAST 里没有 $VERSION"; exit 1; }
  grep -q "releases/download/$SLUG/$VERSION/" "$APPCAST" || { echo "✗ $APPCAST 的下载地址不是 tag $TAG"; exit 1; }
fi

# ---------- 版本说明 ----------
notes() { sed -n 's/^[[:space:]]*-[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/- \1/p' "$1"; }
BODY="$APP $VERSION"
if [ -n "$NOTES_DIR" ]; then
  for l in zh en; do
    f="$NOTES_DIR/$VERSION.$l.md"
    [ -f "$f" ] || { echo "✗ 缺少版本说明 ${f}（中英各一份，每行「- 一条」）"; exit 1; }
    [ -n "$(notes "$f")" ] || { echo "✗ $f 是空的：至少写一条「- 内容」"; exit 1; }
  done
  BODY="$(printf '%s\n\n%s\n' "$(notes "$NOTES_DIR/$VERSION.zh.md")" "$(notes "$NOTES_DIR/$VERSION.en.md")")"
fi

# ---------- Token ----------
TOKEN="${GITHUB_TOKEN:-}"
[ -z "$TOKEN" ] && [ -f .cache/github_token ] && TOKEN="$(<.cache/github_token)"
[ -z "$TOKEN" ] && TOKEN="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p')"
code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" https://api.github.com/user)"
if [ "$code" != 200 ]; then
  cat <<EOF
✗ GitHub Token 无效或已过期。在 https://github.com/settings/tokens/new 生成 repo 权限的 Token，然后任选其一：
  GITHUB_TOKEN=ghp_xxx ./publish.sh $APP_ROOT $VERSION
  printf '%s' 'ghp_xxx' > $APP_ROOT/.cache/github_token && chmod 600 $APP_ROOT/.cache/github_token
EOF
  exit 1
fi
auth=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json")
API="https://api.github.com/repos/$REPO"
json() { python3 -c "import sys,json;d=json.load(sys.stdin);print($1)"; }

echo "==> 发布 $TAG 到 $REPO"

# ---------- Release ----------
payload="$(python3 -c 'import json,sys;print(json.dumps({"tag_name":sys.argv[1],"target_commitish":sys.argv[2],"name":sys.argv[3],"body":sys.argv[4],"make_latest":sys.argv[5]}))' \
  "$TAG" "$BRANCH" "$APP $VERSION" "$BODY" "$MAKE_LATEST")"
REL_ID="$(curl -s "${auth[@]}" "$API/releases/tags/$TAG" | json 'd.get("id") or ""')"
if [ -z "$REL_ID" ]; then
  REL_ID="$(curl -s "${auth[@]}" -X POST "$API/releases" -d "$payload" | json 'd.get("id") or (_ for _ in ()).throw(SystemExit(d))')"
  echo "    已创建 release id=$REL_ID"
else
  curl -s "${auth[@]}" -X PATCH "$API/releases/$REL_ID" -d "$payload" >/dev/null
  echo "    复用已有 release id=$REL_ID"
fi

for f in "${FILES[@]}"; do
  name="$(basename "$f")"
  old="$(curl -s "${auth[@]}" "$API/releases/$REL_ID/assets?per_page=100" | json "next((a['id'] for a in d if a['name']=='$name'),'')")"
  [ -n "$old" ] && curl -s "${auth[@]}" -X DELETE "$API/releases/assets/$old" >/dev/null
  url="$(curl -s "${auth[@]}" -X POST -H "Content-Type: application/octet-stream" --data-binary "@$f" \
    "https://uploads.github.com/repos/$REPO/releases/$REL_ID/assets?name=$name" | json 'd.get("browser_download_url") or d')"
  echo "    ✓ $name -> $url"
done

# ---------- 固定 feed ----------
if [ -n "$APPCAST" ]; then
  path="$SLUG/appcast.xml"
  sha="$(curl -s "${auth[@]}" "$API/contents/$path?ref=$BRANCH" | json 'd.get("sha","") if isinstance(d,dict) else ""')"
  body="$(python3 - "$APPCAST" "$path" "$TAG" "$BRANCH" "$sha" <<'PY'
import json, sys, base64
f, path, tag, br, sha = sys.argv[1:6]
d = {"message": f"{tag}: appcast", "content": base64.b64encode(open(f, "rb").read()).decode(), "branch": br}
if sha: d["sha"] = sha
print(json.dumps(d))
PY
)"
  curl -sf "${auth[@]}" -X PUT "$API/contents/$path" -d "$body" >/dev/null
  echo "    ✓ feed -> https://raw.githubusercontent.com/$REPO/$BRANCH/$path"
fi

# ---------- 官网固定地址 ----------
if [ -n "$SITE_DIR" ]; then
  [ -d "$SITE_DIR" ] || { echo "✗ 缺少官网目录 $SITE_DIR"; exit 1; }
  {
    echo "# 由 macapp-releases/publish.sh 生成：$TAG"
    for f in "${FILES[@]}"; do
      name="$(basename "$f")"
      [[ "$name" == "$APP-$VERSION".* ]] || continue
      echo "/download/$APP.${name#"$APP-$VERSION".} https://github.com/$REPO/releases/download/$TAG/$name 302"
    done
  } > "$SITE_DIR/_redirects"
  [ -n "$APPCAST" ] && cp "$APPCAST" "$SITE_DIR/appcast.xml"
  echo "    ✓ $SITE_DIR/_redirects$([ -n "$APPCAST" ] && echo "、$SITE_DIR/appcast.xml")"
  if [ -n "$PAGES_PROJECT" ]; then
    npx -y wrangler@latest pages deploy "$SITE_DIR" --project-name "$PAGES_PROJECT" --branch main --commit-dirty=true --force 2>&1 | tail -1
  elif [ "$SITE_GIT" = true ]; then
    git add "$SITE_DIR/_redirects" ${APPCAST:+"$SITE_DIR/appcast.xml"}
    git diff --cached --quiet || git commit -q -m "site: 固定下载地址与 appcast 指向 $TAG" "$SITE_DIR/_redirects" ${APPCAST:+"$SITE_DIR/appcast.xml"}
    git push -q && echo "    ✓ 已推送，官网自动部署"
  else
    echo "    官网未配置 PAGES_PROJECT / SITE_GIT：提交并推送 $SITE_DIR 后生效"
  fi
fi

cat <<EOF

完成：https://github.com/$REPO/releases/tag/$TAG
全部版本：https://github.com/$REPO/releases?q=$SLUG%2F&expanded=true
EOF
