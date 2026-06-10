# Inca Treasure Multiplayer

移动端房间码多人版《印加宝藏》原型。当前实现为 Web + Socket.IO，服务端负责权威状态，客户端只展示状态并提交玩家选择。

## 功能范围

- 创建 4 位房间码。
- 通过昵称和房间码加入房间。
- 等待房间展示玩家列表、房主和人数。
- 房主开始游戏，至少 2 名玩家才能开始。
- 服务端统一洗牌、翻牌、结算和排名。
- 玩家在各自设备上提交“继续深入”或“撤退”。
- 决策提交前不公开具体选择，只公开是否已提交。
- 支持 5 轮、宝石牌、危险牌、简化遗物牌和最终排名。
- 客户端不会收到隐藏牌堆，只收到 `deckCount`。

## 安装

PowerShell 中建议使用 `npm.cmd`，避免 `npm.ps1` 执行策略问题。

```powershell
npm.cmd install --cache .\.npm-cache
```

## 本地运行

```powershell
npm.cmd run build
npm.cmd start
```

服务启动后访问：

```text
http://127.0.0.1:4174
```

手机联机测试时，电脑和手机需要在同一局域网。将 `127.0.0.1` 换成电脑局域网 IP，例如：

```text
http://192.168.1.20:4174
```

一名玩家创建房间，其他玩家输入房间码加入。

等待房间里的“复制邀请”会复制带房间码的链接，例如：

```text
http://192.168.1.20:4174/?room=ABCD
```

其他玩家打开链接后，房间码会自动预填，仍需输入昵称后点击加入房间。

## 开发命令

```powershell
npm.cmd run typecheck
npm.cmd run build
npm.cmd run test
```

`npm.cmd run test` 会构建项目并运行多人冒烟测试，覆盖：

- 创建房间。
- 第二名玩家加入。
- 开始游戏。
- 决策阶段提交继续/撤退。
- 验证公开状态不泄露隐藏牌堆。
- 自动推进完整 5 轮并到达最终排名。

## 协议方向

当前 Socket.IO 事件：

- `createRoom`
- `joinRoom`
- `startGame`
- `submitDecision`
- `nextRound`
- `roomJoined`
- `stateUpdated`
- `errorMessage`

后续 Flutter 客户端可以复用这些事件。Flutter 客户端仍应只负责展示和提交意图，不应在客户端自行洗牌、翻牌或结算。

## Flutter 状态

当前机器未安装 Flutter/Dart SDK，无法创建和编译 Flutter 客户端。等 SDK 可用后，建议用 Flutter 作为客户端接入现有 Socket.IO 服务端协议。
