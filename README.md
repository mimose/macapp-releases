# macapp-releases

Release builds of my macOS apps. Source code is private.
各应用的发布包都在这里，tag 统一为 `<应用>/<版本号>`。

| App | | Website | Releases |
|---|---|---|---|
| **Cadence** | Typing, as a performance. 打字，是一场演出。 | [cadenceapp.mimos.top](https://cadenceapp.mimos.top) | [cadence/*](https://github.com/mimose/macapp-releases/releases?q=cadence%2F&expanded=true) |
| **Textime** | A quiet text editor. 写什么格式，就看什么样子。 | [textimeapp.mimos.top](https://textimeapp.mimos.top) | [textime/*](https://github.com/mimose/macapp-releases/releases?q=textime%2F&expanded=true) |

None of the apps are notarized yet. On first launch, macOS will say it can't verify the developer:
**System Settings → Privacy & Security → Open Anyway**. You only need to do this once.
首次打开提示「无法验证开发者」：**系统设置 → 隐私与安全性 → 仍要打开**，只需一次。

---

## Cadence

<p align="center"><img src="assets/cover.png" alt="Cadence — Typing, as a performance" width="800"></p>

Light rises from every key you press. And you can record the take.
Free, 8 MB, Apple silicon & Intel, macOS 13+. Download the `.dmg` from the [latest cadence release](https://github.com/mimose/macapp-releases/releases?q=cadence%2F&expanded=true).

- A quiet strip at the bottom of your screen lights up wherever you press, in any app
- 7 styles: Star Rain, Equalizer, Stream, Ripple, Firework, Blossom, String
- Full-stage keys: make Space or Return set off a wave, sweep or flash
- Record a take: rhythm, peak combo and hand balance; replay it or export a vertical poster

<p align="center"><img src="assets/styles.png" alt="Seven styles" width="800"></p>

**Privacy.** Cadence needs **Input Monitoring**, but reads key codes only — never characters — and goes silent in password fields.
Takes stay on your Mac. Only update checks go online, and you can turn them off. Crash reports are opt-in.

**中文.** 每次按键，屏幕底部对应的位置都会升起一束光；还能把这一段录下来。七种风格；空格、回车可以触发全场效果；录下的片段可回放、可导出竖屏海报。只读键码，读不到你打的字；密码框里自动静默；片段只存在本机；只有检查更新会联网（可关）；崩溃报告需同意才发送。

The app updates itself. Its Sparkle feed is [`cadence/appcast.xml`](cadence/appcast.xml).

---

## Textime

A quiet text editor for macOS. It recognizes Markdown, JSON, YAML, CSV, TOML and PlantUML by extension — write on the left, see on the right.
Free, 2 MB, Apple silicon & Intel, macOS 13+. Download the `.zip` from the [latest textime release](https://github.com/mimose/macapp-releases/releases?q=textime%2F&expanded=true), unzip and drag Textime into Applications.

- Preview by format, with errors marked on the line they occur
- Encoding detection and switching, line endings, search and replace with newlines
- Split a selection into lines and edit with many carets
- Unsaved work is kept across restarts; conflicts with the file on disk are detected

**中文.** 按后缀识别格式，边写边预览；编码识别与切换；搜索替换支持换行符；拆分为行、多光标编辑；未保存的内容自动暂留，重启后恢复并检测与磁盘文件的冲突。不联网收集任何数据。

---

## Publishing

```bash
./publish.sh <app source dir> <version>     # e.g. ./publish.sh ../textime 0.1.6
```

Each app keeps a `release.conf` in its source root (name, tag prefix, assets, release notes). See the header of [`publish.sh`](publish.sh).
