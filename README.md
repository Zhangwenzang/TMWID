# TMWID - Tell Me When It's Done

一个 macOS 菜单栏应用，实时监控你所有的 Claude Code 会话状态。像素风动画告诉你 Claude 在干嘛，你可以安心去做别的事，该回来的时候自然知道。

## 它能干什么

TMWID 常驻菜单栏，自动发现并追踪所有活跃的 Claude Code 会话 -- 终端、IDE 都行。三种状态，三套动画：

- **Working** -- Claude 正在思考/写代码。去倒杯水吧。
- **Ask** -- Claude 需要你回应（权限确认、提问）。该回来看看了。
- **Done** -- 任务完成。去验收成果吧。

状态切换时有音效提示（可关），还有一个浮动气泡窗口让你随时瞟一眼当前状态。

## 安装

从 [Releases](https://github.com/Zhangwenzang/TMWID/releases) 下载最新 `.dmg`，打开后拖 **Tmwid** 到 Applications。

首次启动会自动注入 Claude Code hook，你已有的 hook 不受影响。

### 遇到"Tmwid.app 已损坏，无法打开"？

这是 macOS Gatekeeper 拦截了未公证的应用，不是真的损坏。打开终端执行：

```bash
sudo xattr -rd com.apple.quarantine /Applications/Tmwid.app
```

输入登录密码后回车，之后双击即可正常打开。

如果上述命令无效，可以试着先卸载再重装：

```bash
sudo rm -rf /Applications/Tmwid.app
# 重新从 DMG 复制
sudo xattr -rd com.apple.quarantine /Applications/Tmwid.app
```

## 状态预览

https://github.com/Zhangwenzang/TMWID/raw/main/assets/demo-states.mp4

## 系统要求

- macOS 13 (Ventura) 或更高版本
- Claude Code（终端或 IDE 均可）

## 设置

通过菜单栏图标进入：

- **Sound** -- 开关状态切换音效
- **Bubble** -- 开关浮动状态气泡窗口

## 卸载

1. 点菜单栏图标 -> **Quit**（自动移除注入的 hook）
2. 删除 `/Applications/Tmwid.app`
3. `rm -rf ~/.tmwid`

## License

MIT
