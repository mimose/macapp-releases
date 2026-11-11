#!/usr/bin/env bash
# 给更新包做 EdDSA 签名并生成只含最新一条的 appcast.xml（Sparkle 2）
#
# 用法：tools/make-appcast.sh <App.zip> <SLUG> <版本> <build号> <版本说明目录> <私钥文件> <输出 appcast.xml>
#   下载地址：https://github.com/mimose/macapp-releases/releases/download/<SLUG>/<版本>/<zip 文件名>
#   版本说明：<目录>/<版本>.zh.md、<版本>.en.md，每行「- 一条」；更新窗口按系统语言显示
#   签名工具：SIGN_UPDATE（默认取应用目录下 vendor/bin/sign_update）
set -euo pipefail
ZIP="$1" SLUG="$2" VERSION="$3" BUILD="$4" NOTES="$5" KEY="$6" OUT="$7"
SIGN_UPDATE="${SIGN_UPDATE:-vendor/bin/sign_update}"
REPO="${RELEASE_REPO:-mimose/macapp-releases}"
[ -f "$KEY" ] || { echo "✗ 缺少 EdDSA 私钥 $KEY"; exit 1; }
LINE="$("$SIGN_UPDATE" "$ZIP" -f "$KEY")"
SIG="$(echo "$LINE" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
[ -n "$SIG" ] || { echo "✗ 签名失败：$LINE"; exit 1; }
python3 - "$ZIP" "$SLUG" "$VERSION" "$BUILD" "$NOTES" "$OUT" "$SIG" "$REPO" <<'PY'
import sys, os, html
zp, slug, ver, build, notes, out, sig, repo = sys.argv[1:9]
name = os.path.basename(zp)
def ul(lang):
    p = f"{notes}/{ver}.{lang}.md"
    items = [l.strip()[1:].strip() for l in open(p, encoding="utf-8") if l.strip().startswith("-")] if os.path.exists(p) else []
    return "<ul>" + "".join(f"<li>{html.escape(i)}</li>" for i in items) + "</ul>"
app = os.path.splitext(name)[0].rsplit("-", 1)[0]
open(out, "w", encoding="utf-8").write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>{app}</title>
    <item>
      <title>{ver}</title>
      <description><![CDATA[{ul("en")}]]></description>
      <description xml:lang="zh-Hans"><![CDATA[{ul("zh")}]]></description>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{ver}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/{repo}/releases/download/{slug}/{ver}/{name}" length="{os.path.getsize(zp)}"
                 type="application/octet-stream" sparkle:edSignature="{sig}"/>
    </item>
  </channel>
</rss>
""")
print("appcast:", out)
PY
