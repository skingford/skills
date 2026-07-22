---
name: go-zero-api
description: go-zero HTTP API 服务的通用 Schema 规范 — .api 文件组织与命名规范（CRUD 动词收敛、Req/Resp 类型、路由）、统一响应 envelope、错误码分段设计、JWT 鉴权与密码加密传输、分页/ID/时间等数据约定、logic 层 copier 数据映射范式、goctl/swagger 工作流。新建 go-zero API 服务、为现有服务补规范、或编写对接客户端时加载本 skill。
---

# go-zero API 通用规范

适用于所有基于 go-zero（`goctl api`）的 HTTP API 服务。目标：任何按本规范搭建的服务，对接方拿到这份文档即可写出正确的请求/响应处理代码，无需读服务端源码。

三类使用场景：

- **新建服务**：按 §1–§8 逐项落地，用 §10 checklist 验收
- **现有服务补规范**：对照 checklist 找差距，逐项对齐
- **编写对接客户端**：只需读 §3（envelope）、§4（错误码）、§5（鉴权）、§6（数据约定）

## 1. `.api` 文件组织

```
services/<name>/
├── <name>.api          # 主文件：只做 import 汇总 + 空 service 声明
├── desc/               # 按业务模块拆分，一个模块一个文件
│   ├── base.api        # 公共类型（必须第一个 import）
│   ├── auth.api
│   └── <module>.api
└── internal/           # goctl 生成 + 手写 logic
```

规则：

- **一个业务模块一个 `.api` 文件**，放 `desc/` 下；主文件只 import，不写类型
- **`base.api` 必须排在主文件 import 列表第一位**——goctl-swagger 在下游文件先于被依赖文件注册时会误报 "import cycle not allowed"
- 每个字段写中文注释，标注格式、单位、字典 key、可选语义

`base.api` 公共类型模板（直接复制）：

```api
syntax = "v1"

info (
	desc: "公共"
)

type (
	IdReq {
		Id string `path:"id"` // 资源 ID（雪花算法,字符串传输避免 JS 精度丢失）
	}
	IdResp {
		Id string `json:"id"` // 创建/操作返回的资源 ID
	}
	BaseFind {
		Skip  int64 `form:"skip,default=0,range=[0:]"`   // 分页偏移:跳过的条数,默认 0
		Limit int64 `form:"limit,default=20,range=[1:]"` // 分页大小:默认 20,上界由 logic 层 clamp
	}
	TimeRangeFilter {
		CreatedAtGte *string `form:"created_at_gte,optional"` // 创建时间下界(RFC3339,含),nil=不限
		CreatedAtLte *string `form:"created_at_lte,optional"` // 创建时间上界(RFC3339,含),nil=不限
	}
)
```

常用 goctl 命令（建议进 Makefile）：

```makefile
gen:
	cd services/<name> && goctl api go -api <name>.api -dir . -style=go_zero
fmt-api:
	cd services/<name> && goctl api format --dir <name>.api
swagger:
	cd services/<name> && goctl api plugin -plugin goctl-swagger="swagger -filename <name>.json" -api <name>.api -dir ./swagger
```

## 2. `.api` 命名规范

### 2.1 CRUD handler 动词收敛（强制）

5 类标准 CRUD 操作固定用下列动词前缀，**不允许同义词**：

| 操作 | handler 前缀 | HTTP 方法 | 典型路径 | 示例 |
|---|---|---|---|---|
| 列表（分页/过滤） | `List` | `GET` | `get /<resource>` | `ListUsers` |
| 创建 | `Create` | `POST` | `post /<resource>` | `CreateUser` |
| 详情（按主键） | `Get` | `GET` | `get /<resource>/:id` | `GetUser` |
| 更新 | `Update` | `PUT` | `put /<resource>/:id` | `UpdateUser` |
| 删除 | `Remove` | `DELETE` | `delete /<resource>/:id` | `RemoveUser` |

**HTTP 方法与 handler 名解耦**：`.api` 里写 `put` / `delete`（HTTP 语义），`@handler` 名走 `Update*` / `Remove*`。handler 名永远不暴露 HTTP 方法。

禁用前缀：`Put*`、`Patch*`、`Delete*`（→ `Remove*`）、`Modify*`/`Edit*`（→ `Update*`）、`Fetch*`/`Find*`/`Query*`/`Show*`（→ `List*`/`Get*`）、`New*`（→ `Create*`）、`Destroy*`/`Erase*`/`Drop*`（→ `Remove*`）。

**软删/硬删是 repo 层实现细节**：HTTP 层统一 `delete` + `Remove*`，`.api` 中禁止出现 `SoftRemove` 字样，客户端不感知删除是软是硬。

### 2.2 非 CRUD 的领域动作动词（允许清单）

状态迁移、关系操作、外部副作用类端点用语义化动词，不硬塞进 CRUD：

| 类别 | 动词 | 示例 |
|---|---|---|
| 关系操作 | `Add` / `Remove` / `Replace` / `Assign` | `AddPoolContents` |
| 订阅 | `Subscribe` / `Unsubscribe` | `SubscribeUserTheme` |
| 生命周期 | `Publish` / `Archive` / `Restore` / `Revoke` / `Reset` | `PublishRelease` |
| 状态切换 | `Pause` / `Resume` / `Claim` / `Resolve` / `Close` | `PauseRollout` |
| 强制动作 | `Force*` | `ForceLogout` |
| 数据进出 | `Upload` / `Import` / `Export` / `Download` | `ImportDevices` |
| 鉴权/会话 | `Login` / `Logout` / `Refresh` | `RefreshToken` |
| 统计 | `Stat` | `StatDevices` |
| 单字段精确调整 | `Set<Field>` | `SetFirmwarePercent` |

选择标准：能被「实体增删改查」完整表达 → CRUD 动词；描述「状态迁移 / 关系链接 / 外部副作用」→ 领域动词；只调整单个核心业务字段 → `Set<Field>` 优于 `Update<Resource>`。

### 2.3 请求 / 响应类型命名

- 后缀统一短形 **`Req` / `Resp`**；**禁止** `Request` / `Response` / `Param(s)` / `Result` / `Reply`
- **类型名前缀 == handler 名前缀**：`@handler UpdateUserProfile` ↔ `UpdateUserProfileReq`
- 纯列表元素类型（无独立详情端点）可命名 `XxxItem`；一旦开出 `get /:id` 详情端点，统一改用 `GetXxxResp`

**何时建专属类型、何时复用通用类型（决策矩阵）**：

| 操作 | Req | Resp |
|---|---|---|
| List | 专属 `ListXxxReq`（embed `BaseFind` + 过滤字段） | 专属 `ListXxxResp`（只含 `Items`，**不返回 `Total`**） |
| Get | **复用 `IdReq`**，禁止新建只含 `Id` 的专属 Req | 专属 `GetXxxResp`（可被 `ListXxxResp.Items` 复用） |
| Create | 专属 `CreateXxxReq` | **复用 `IdResp`**，仅需回传额外业务字段才建专属 |
| Update | 专属 `UpdateXxxReq`（path id + 可选字段） | **复用 `IdResp`** |
| Remove | **复用 `IdReq`** | **复用 `IdResp`** |
| 子资源/多锚点 | 单锚点复用统一锚点类型（如 `DeviceIdReq`，全服务统一命名）；双锚点或带额外参数建专属 | 按对应操作执行 |

口诀：**请求形状能被通用锚点类型完整表达 → 复用；多任何一个字段 → 专属。响应默认 `IdResp`，有业务字段才专属。**

### 2.4 Resp 字段规则（强制）

- **响应契约必须是固定 schema**：零值显式输出（`""` / `0` / `false` / `[]`），绝不省键——客户端不需要处理「键可能不存在」
- **Resp 字段禁止指针**；nullable 列的 nil → 零值适配在 logic 层完成，不外泄到契约
- **指针 + `,optional` 只属于 Req 一侧**（nil = 不改 / 不过滤）
- **全部 `.api` 禁 `json:",omitempty"`**（Req 可选性用 go-zero 的 `,optional` 表达）；`validate:"omitempty,..."` 是校验器标签，合法保留

### 2.5 资源路径命名

- **复数 kebab-case**：`/sys-users`、`/audit-logs`、`/firmware-releases`
- `:id` 段单数，子资源嵌在条目下：`put /:id/password`、`delete /:id/slot-images/:slot_id`
- 无尾斜杠；统一版本前缀（`/v1`）

### 2.6 handler ↔ logic 文件 1:1

`@handler XxxYyy` ↔ `internal/logic/<group>/xxx_yyy_logic.go`（snake_case）↔ `XxxYyyLogic` struct。重命名时三处同步。logic 目录下只允许 `*_logic.go` 文件。

### 2.7 CI / Review grep 兜底

编辑 `.api` 后跑这组 grep，**必须全部 0 匹配**：

```bash
# 禁用 handler 前缀
grep -rnE "@handler\s+(Put|Patch|Delete|Modify|Edit|Fetch|Find|Query|Show|Destroy|Erase|Drop)[A-Z]" services/*/desc/
# 禁用类型后缀全词
grep -rnE "(Request|Response|Param|Params|Result|Reply)\s*\{" services/*/desc/
# 禁用 HTTP 方法
grep -rnE '^\s*(patch|head|options|connect|trace)\s+' services/*/desc/
# 尾斜杠路径（goctl 生成后查 routes.go）
grep -nE 'Path:\s+"/[^"]*/"' services/*/internal/handler/routes.go
# 禁 json omitempty
grep -rnE 'json:"[a-z_0-9]+,omitempty"' services/*/desc/
# SoftRemove 不进 HTTP 层
grep -rn 'SoftRemove' services/*/desc/
```

## 3. 统一响应格式（Envelope）

所有端点响应统一包一层 `BaseResponse`。`.api` 文件与 swagger 中声明的响应类型只是 `data` 内层——这层包装由全局钩子注入，契约文档必须显式说明。

```json
// 成功（HTTP 200）
{
  "data": { ... },          // .api 声明的业务 payload；无返回体端点为 null
  "err_code": 0,
  "err_msg": "success",
  "trace_id": "abc123..."   // 链路追踪 ID，报障时带上
}

// 失败（HTTP 4xx/5xx）
{
  "data": null,
  "err_code": 4001,         // 业务错误码，见 §4
  "err_msg": "密码错误",     // 面向用户的文案（可 i18n），客户端可直接展示
  "trace_id": "abc123..."
}
```

**客户端判断成败只看 `err_code == 0`，HTTP 状态码仅作参考。**

服务端接线（bootstrap 阶段，三个全局钩子）：

```go
// 结构定义（放共享包，如 internal/httputil）
type BaseResponse struct {
	Data    any    `json:"data"`
	ErrCode int    `json:"err_code"`
	ErrMsg  string `json:"err_msg"`
	TraceID string `json:"trace_id"`
}

// 1. 成功响应统一包装
httpx.SetOkHandler(func(ctx context.Context, v any) any {
	return BaseResponse{Data: v, ErrCode: 0, ErrMsg: "success", TraceID: traceIDFrom(ctx)}
})

// 2. 接线 go-playground/validator，让 .api 中 validate tag 生效；
//    校验失败由错误钩子统一映射为 400 + 中文 err_msg
httpx.SetValidator(newValidator())

// 3. 错误响应统一包装（CodeError → 对应状态码 + envelope）
httpx.SetErrorHandlerCtx(errorHandler)
```

## 4. 错误码设计

### 4.1 分段方案

| 码段 | 含义 |
|---|---|
| `0` | 成功 |
| `1xxx` | 系统 / 参数 / 通用（约定 `1000` 服务异常兜底，`1010` 参数错误） |
| `4xxx` | 登录 / 账号鉴权 |
| `10xxx` | 数据库 |
| `40xxx` 起 | 业务域，按域分小段（如 40100-40199 内容域、40200-40299 设备域） |

要求：

- 错误码集中在一个文件定义（如 `internal/errorx/codes.go`），常量 + 中文注释，禁止散落魔法数字
- 码段划分写在该文件包注释里，新增域先占段再用
- 敏感场景（如设备鉴权）可采用「错误响应隐藏」策略：对外统一返回一个模糊错误码，内部细分错误码只进审计/监控日志

### 4.2 CodeError 结构要点

自定义错误类型建议区分四层文案，避免内部信息泄漏：

| 字段 | 去向 |
|---|---|
| `ErrMsg` / `detail` | 下发客户端，可展示给用户 |
| `msgKey` + `msgArgs` | i18n 翻译 key，HTTP 出口按请求 locale 本地化 |
| `reason` | **仅进服务端日志**，排查用，永不下发 |
| `cause` | error chain，供 `errors.Is/As` |

### 4.3 HTTP 状态码映射

| 情形 | HTTP 状态 |
|---|---|
| 成功 | 200 |
| `err_code` 本身是合法 HTTP 状态码（如 404、423） | 直接用作状态码 |
| 已注册的业务错误码 | 400 |
| 未注册的未知错误 | 500 |
| 未登录 / token 失效 | 401 |
| 权限不足 | 403 |
| 限流 | 429 |

## 5. 鉴权模式

### 5.1 JWT Bearer

- 路由级声明：`@server` 块加 `jwt: JwtAuth`；需要认证的模块全部声明，白名单（登录、健康检查）除外
- 请求头：`Authorization: Bearer <JWT>`
- **`aud` 隔离**：多服务共用签名密钥时，JWT 必须带 `aud` 且各服务强校验，拒绝跨服务 token 复用
- **会话吊销**：登出/改密后旧 token 立即失效（服务端 session 校验），所有环境一律强制，不给 dev 开后门
- token 失效返回 401，客户端跳转重新登录

### 5.2 密码加密传输（管理端登录推荐）

密码不明文过线，三步流：

```
1. GET  /v1/auth/captcha            → 图形验证码（响应头 no-store）
2. GET  /v1/auth/login/public-key   → RSA 公钥 + key_version（支持 ETag/304 缓存）
3. POST /v1/auth/login              → username + password_encrypted + 验证码
```

- 加密：**RSA-OAEP-SHA256** 加密原始密码后 base64，字段名约定 `password_encrypted` / `new_password_encrypted`
- 公钥带版本号，版本不匹配返回专用错误码，客户端重取公钥重试
- 连续失败触发登录锁定；创建/改密接口同样走加密字段，解密后明文长度 ≥ 8

## 6. 数据处理约定

### 6.1 ID：雪花算法，字符串传输

资源 ID 服务端为 int64（雪花算法），**请求/响应 JSON 中一律字符串**，避免 JS Number 精度丢失：

```json
{ "id": "1867423589234567168" }
```

### 6.2 分页：skip / limit

- query 参数 `skip`（默认 0）+ `limit`（默认 20）
- **limit 上界在 logic 层 clamp**，传大值不报错、静默截断
- 响应只含 `items` 数组，**不返回 `total`**（避免每页多付一次 COUNT 开销）；用「返回条数 < limit」判底，前端分页器走「上一页/下一页」形态而非总页数跳页

### 6.3 时间：RFC3339 UTC

- 响应时间字段（`created_at` / `updated_at` …）统一 RFC3339 UTC 字符串，展示时客户端转本地时区
- 范围过滤参数命名固定：`<field>_gte` / `<field>_lte`（含边界，不传 = 不限）

### 6.4 可选参数语义（指针字段）

- `.api` 中可选字段用指针 + `optional` tag
- 列表过滤：nil = 不过滤该维度
- PUT 更新：nil = 不修改该字段（partial update），显式传值 = 改为该值
- 枚举字段加 `options=1|2` 约束，非法值直接 400

### 6.5 参数校验

- `.api` 字段用 `validate:"..."` 声明规则，配 `err_msg:"..."` 中文文案
- 校验失败返回 400 + `err_msg`，客户端可直接透传展示

### 6.6 字典驱动的枚举

状态类字段取值含义不硬编码进文档/前端，走字典接口：

- 提供 `GET /v1/dictionaries/bundle` 一次拉全量（前端启动时加载）
- 字段注释标注字典 key，如 `见字典 sys_user_status`

### 6.7 列表过滤纪律

- **没有 `keyword` 大杂烩参数**；每个 list 端点只暴露命名的、有索引的列作为过滤器
- 禁止 leading-wildcard LIKE（`LIKE '%x%'` 全表扫描）
- slice 类型 query 参数用 CSV 编码（`?ids=1,2,3`）

## 7. Logic 层数据映射（copier 范式）

Req → repo 入参、model → Resp 的字段映射**统一用 [jinzhu/copier](https://github.com/jinzhu/copier)**，禁止 logic 里手工逐字段拼装。这是消除样板代码和「加字段忘同步」bug 的核心手段。

### 7.1 入参方向：Req → repo 查询/写入参数

标准范式是**纯 `copier.Copy`**，仅字段名或来源不匹配时手工覆盖个别字段：

```go
var in repo.ListUserIn
if err := copier.Copy(&in, req); err != nil {
	return nil, errorx.NewCopierError(err)
}
in.OperatorId = l.ctx.Value(...) // 仅补 req 上没有的字段
```

### 7.2 响应方向：model → Resp（Get / List / Search 端点）

**触发条件（任一满足即必须走 copier，不许手拼）**：

1. 响应含时间字段（`time.Time` / `*time.Time` 源 → 字符串目标）——哪怕只有 2 个字段
2. 响应字段 ≥ 3 个

用 `copier.CopyWithOption` + **自建转换器工厂包**（如 `pkg/copierx`）统一类型转换：

```go
opt := copier.Option{
	Converters: []copier.TypeConverter{
		copierx.TimeToStr(),    // time.Time  → RFC3339 UTC 字符串（零参默认）
		copierx.TimePtrToStr(), // *time.Time → 字符串（nil → ""）
		copierx.StrPtrToStr(),  // *string    → string（nil → ""）
	},
}

// Get 端点：单条直拷
if err := copier.CopyWithOption(&resp, item, opt); err != nil {
	return nil, errorx.NewCopierError(err)
}

// List 端点：整切片一次直拷（copier 保序，list[i] 对 items[i]）
list := make([]types.GetUserResp, 0, len(items))
if err := copier.CopyWithOption(&list, items, opt); err != nil {
	return nil, errorx.NewCopierError(err)
}
for i, it := range items {
	list[i].SyncStatus = derive(it) // 仅补 copier 无源可拷的派生字段
}
```

### 7.3 禁止模式

- **禁止** list 端点 for 循环逐条 copier 或逐条 `resp.X = item.X` 字段拼装——整切片一次直拷
- **禁止**散落的手工时间格式化（`.Format(time.RFC3339)` / 自建 FormatTime 工具）——时间转换只走转换器工厂，全服务统一 RFC3339+UTC
- **禁止** copier 之后再手工 deref 指针——`*T ↔ T`、枚举 → int 是 copier v0.4+ 原生能力
- 需要跳过部分行（如关联指向已删资源）：先按序过滤出源切片再整体直拷，不要退回逐条 copier
- **不适用场景**：Create / Update / Remove 的响应（`IdResp` 仅 1~2 字段，套 copier 反而冗余），直接构造

### 7.4 转换器工厂包建议清单

新项目建一个 `pkg/copierx`，收敛这几个 `copier.TypeConverter` 工厂：

| 工厂 | 转换 | 默认行为 |
|---|---|---|
| `TimeToStr()` | `time.Time` → `string` | RFC3339 + UTC |
| `TimePtrToStr()` | `*time.Time` → `string` | nil → `""` |
| `StrPtrToStr()` | `*string` → `string` | nil → `""`（显式挂法自文档化，保留） |
| `EnumToInt64[T]()` | 自定义枚举 → `int64` | 类型精确派发 |

## 8. Swagger 生成与暴露

- `make swagger`（goctl-swagger 插件）生成 OpenAPI JSON，供导入 Postman / 生成客户端
- swagger 中的响应类型是 `data` 内层，**外层 envelope（§3）swagger 表达不了**，对接文档必须单独说明
- swagger UI 路由**仅非生产环境挂载**，避免对外泄露完整 API 契约

## 9. 新项目落地 checklist

- [ ] `desc/` 按模块拆分 `.api`，`base.api` 第一个 import，公共类型复用模板
- [ ] handler 动词收敛：CRUD 只用 List/Create/Get/Update/Remove，领域动作按允许清单；无禁用前缀（§2.7 grep 全 0 匹配）
- [ ] 类型命名：短形 Req/Resp、前缀对齐 handler、按决策矩阵复用 IdReq/IdResp；Resp 无指针、全文件无 `json:",omitempty"`
- [ ] 路由：复数 kebab-case、无尾斜杠、统一版本前缀、只用 GET/POST/PUT/DELETE
- [ ] `SetOkHandler` / `SetErrorHandlerCtx` / `SetValidator` 三钩子接线，envelope 结构一字不差
- [ ] 错误码集中定义 + 分段注释，无魔法数字；CodeError 区分对外文案与内部 reason
- [ ] JWT 带 `aud` 强校验 + 会话吊销；管理端登录走 RSA 密码加密三步流
- [ ] ID 字符串化、skip/limit 分页 + clamp、RFC3339 UTC、`*_gte/*_lte`、指针 optional 语义
- [ ] validate + err_msg 中文校验文案；枚举走字典接口；list 过滤只暴露索引列
- [ ] logic 层映射统一 copier：入参纯 `Copy`、Get/List 响应 `CopyWithOption` + 转换器工厂；list 整切片直拷、无手工时间格式化
- [ ] swagger 可生成，生产不挂载 UI；对接文档说明 envelope 外层
