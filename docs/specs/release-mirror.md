# 正式版镜像到 R2

> 关联: ADR-0004（一个 Apple 芯片安装包与它自己的 Sparkle appcast）、ADR-0020（正式版的 DMG 与 appcast 由下载域名提供）

## Problem Statement

随译的安装包在维护者的 Mac 上签名并公证，发布到 GitHub Release。官网的新访客和已安装 App 的自动更新都要从一个稳定、受维护者控制的地址取到同一个版本的安装包，而且取到的字节必须正是发布的那一份；一个写错的地址或一份半上传的文件，会让用户下载到不存在的包，或让已安装的 App 收到无法更新的指引。

## Solution

GitHub 上发布一个正式版后，一条工作流把这个版本的 DMG 和 appcast 复制到 Cloudflare R2，经下载域名公开。它先让 DMG 经下载域名可读并逐字节核对，再换上 appcast，最后才更新官网读取的最新版指针，所以官网和已安装 App 永远不会被指向一个还没有就绪的文件。

## Functional Requirements

### release-mirror::REQ-001 哪些发布会被镜像

维护者在 GitHub 上发布一个版本后，工作流镜像它；维护者也可以按 tag 手动重跑。

- release-mirror::REQ-001/AC-01：发布的版本是正式版（tag 为 `v` 加 `主.次.修订`，没有后缀，不是草稿，不是预发布）时，工作流运行。
- release-mirror::REQ-001/AC-02：tag 带后缀、或发布是预发布时，不向 R2 写任何东西。手动重跑给出这样的 tag，工作流失败。
- release-mirror::REQ-001/AC-03：GitHub 发布除该版本的 DMG 和 appcast 外还带别的文件时，别的文件不被镜像；缺 DMG 或缺 appcast 时，工作流失败，不向 R2 写任何东西。

### release-mirror::REQ-002 R2 里放什么、放在哪

下载域名的根就是 R2 桶的根。

- release-mirror::REQ-002/AC-01：DMG 在 `releases/v<版本>/JustSnap-<版本>-mac-arm64.dmg`，响应带 `Cache-Control: public, max-age=31536000, immutable`。
- release-mirror::REQ-002/AC-02：appcast 在 `appcast/appcast-arm64.xml`，最新版指针在 `latest.json`，两者的 `Cache-Control` 都是 `public, max-age=300`。
- release-mirror::REQ-002/AC-03：指针的内容与官网读取它的要求一致（landing-page::REQ-001/AC-01 与该 spec 的“最新版指针”）。

### release-mirror::REQ-003 先核对，后指向

一个文件只有在它所依赖的文件已经就绪并核对过之后才被换上。

- release-mirror::REQ-003/AC-01：DMG 上传之后，从下载域名读回，大小和 sha256 与 GitHub 发布里的那份一致，才继续。
- release-mirror::REQ-003/AC-02：appcast 只在下列各项都成立时才写入：只有一个 enclosure；它的地址恰为该版本 DMG 在下载域名上的地址；它的 `length` 等于 DMG 的大小；它的 `sparkle:shortVersionString` 等于该版本；它带非空的 `sparkle:edSignature`。
- release-mirror::REQ-003/AC-03：写入的顺序是 DMG、appcast、最新版指针；任何一步失败，后面的都不写。

### release-mirror::REQ-004 最新版指针不回退

- release-mirror::REQ-004/AC-01：下载域名上的最新版指针已经指向更高的版本时，把较低的版本镜像进来是失败，不向 R2 写任何东西。
- release-mirror::REQ-004/AC-02：指针不存在、读不了或内容畸形时，不构成阻止；工作流照常写入。

### release-mirror::REQ-005 失败要可见，也要能重跑

- release-mirror::REQ-005/AC-01：任一步失败，运行以失败结束；不存在“跳过镜像仍算成功”的路径。
- release-mirror::REQ-005/AC-02：同一版本重跑，结果与第一次成功运行相同。

## Constraints

### release-mirror::CON-001 R2 凭据缺失时失败（直接验收）

适用范围：镜像工作流。R2 账号、桶或访问密钥缺失时，工作流以失败结束，不跳过。

### release-mirror::CON-002 appcast 的公开地址不变（直接验收）

适用范围：每个正式版。appcast 的公开地址是 `https://dl.justsnap.aloongplanet.com/appcast/appcast-arm64.xml`；已安装的 App 内置这个地址（ADR-0004），所以它不随版本变化，也不迁移。

## 失败模式与边界

**序列 A：一次镜像运行**

- A1 DMG 上传到一半中断 → 指针与 appcast 保持不变；重跑从头上传同一个对象（release-mirror::REQ-003/AC-03、release-mirror::REQ-005/AC-02）。
- A2 下载域名读回的 DMG 大小或 sha256 与发布的不同 → 失败，appcast 与指针不变（release-mirror::REQ-003/AC-01）。
- A3 DMG 上传后下载域名暂时读不到 → 读回最多重试三次，每次间隔十秒，仍读不到则失败（release-mirror::REQ-003/AC-01）。
- A4 appcast 的版本、地址或长度与 DMG 不一致，或没有签名 → 失败，不向 R2 写任何东西（release-mirror::REQ-003/AC-02）。
- A5 两个正式版几乎同时发布 → 两次运行依次执行，不并行；后一次按 release-mirror::REQ-004 判断是否回退。
- A6 重跑一个已被更高版本取代的旧版本 → 失败（release-mirror::REQ-004/AC-01）；要有意回退，必须由维护者手动处理，不属于本工作流。
- A7 appcast 已写入但指针没有写成 → 已安装的 App 开始更新，官网仍给上一个版本；重跑写成指针即可恢复（release-mirror::REQ-005/AC-02）。

## Implementation Decisions

- **GitHub 发布的资产**：维护者在本机运行发布命令得到 `JustSnap-<版本>-mac-arm64.dmg` 和 `appcast-arm64.xml`，原样作为 GitHub 发布的资产上传。工作流只下载这两个，镜像的就是这两份。
- **appcast 里的下载地址**：本机出包时，`DOWNLOAD_BASE_URL` 取 `https://dl.justsnap.aloongplanet.com/releases/v<版本>`，`APPCAST_BASE_URL` 取 `https://dl.justsnap.aloongplanet.com/appcast`，使 appcast 的 enclosure 恰为该版本 DMG 在下载域名上的地址（release-mirror::REQ-003/AC-02）。
- **触发**：GitHub 的 `release` 事件的 `published` 类型，和带 `tag` 输入的手动触发。运行串行（同一并发组，不取消进行中的运行）。
- **凭据**：R2 的账号、桶和访问密钥取自仓库的 `R2_ACCOUNT_ID`、`R2_BUCKET`、`R2_ACCESS_KEY_ID`、`R2_SECRET_ACCESS_KEY`；它们由基础设施仓库的 Terraform 写入。
- **版本比较**：按 `主.次.修订` 三个整数逐项比较。

## Out of Scope

- 本机出包、签名、公证与 Sparkle 签名：由发布命令完成（macos-distribution），本 spec 只管发布之后。
- 预发布版本向 R2 的镜像：目前没有预发布通道（landing-page 的 Out of Scope）。
- 有意回退指针：没有这个需求，出现时由维护者手动处理。
- Intel 与 Universal 包：只有一个 Apple 芯片安装包（ADR-0004）。

## Further Notes

- 官网从下载域名读取最新版指针的行为属官网 spec（landing-page::REQ-001）。
