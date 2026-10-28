# Admin UX 可选规范目录

> **基线**（必做）见 `rules/std-admin-ux.mdc`，不在本目录重复。  
> 本文件由 `cursor-std configure-admin-ux` 读取（`$STANDARDS_HOME` / `--source`），按项目勾选生成 `.cursor/rules/admin-ux.local.mdc`。  
> 新增规范：追加条目即可；升格为基线时移入 `std-admin-ux` 并从此处删除或标废弃。

机器可读约定：

- ` ```option ` … ` ``` `：元数据（`id` / `kind` / `title` / 可选 `choices`）
- `kind: flag`：勾选 `- [x] ID`
- `kind: choice`：勾选 `- [x] ID=choice`（`choices` 逗号分隔）
- ` ```rule ` … ` ``` `：flag 的正文
- ` ```rule:CHOICE ` … ` ``` `：choice 某一取值的正文

---

## B · 推荐约定

### B1 · 列表返回保留查询上下文

```option
id: B1
kind: flag
title: 列表返回保留查询上下文
```

```rule
从列表进入详情（或编辑）再返回时，保留筛选条件与页码；滚动位置尽力恢复。
```

### B5 · 选项较多的 Select 可搜索

```option
id: B5
kind: flag
title: 选项较多的 Select 可搜索
```

```rule
下拉选项超过 8 个时开启可搜索（如 filterable / showSearch）；远程搜索须防抖。
```

### B6 · 脏表单关闭二次确认

```option
id: B6
kind: flag
title: 脏表单关闭二次确认
```

```rule
弹窗/抽屉内表单有未保存修改时，关闭或取消须二次确认「是否放弃修改」；无修改可直接关。
```

### B8 · 权限控制可见性

```option
id: B8
kind: flag
title: 权限控制可见性
```

```rule
无权限的操作：隐藏或禁用（项目统一一种）；直链访问无权限页显示 403（或等价），禁止假装操作成功。
```

---

## C · 项目习惯

### C1 · 列表一屏展示

```option
id: C1
kind: flag
title: 列表一屏展示
```

```rule
列表页避免页面级竖向滚动：筛选区 + 表体在一屏内，表体内部滚动（按项目布局计算表高）。
```

### C2 · 筛选触发方式

```option
id: C2
kind: choice
title: 筛选触发方式
choices: click-search,change-search
```

```rule:click-search
筛选项变更后须点击「查询」（或等价）才发请求；文本框 Enter 仍触发查询（与基线一致）。
```

```rule:change-search
筛选项变更即触发查询；文本类输入须防抖（建议 300–500ms），避免逐字打请求。
```

### C3 · 新建/编辑承载方式

```option
id: C3
kind: choice
title: 新建/编辑承载方式
choices: modal,drawer,page
```

```rule:modal
默认用居中弹窗承载新建/编辑表单（字段较少、一屏可完成时）。
```

```rule:drawer
默认用抽屉承载新建/编辑（字段中等、需与列表对照时）。
```

```rule:page
默认用独立页面承载新建/编辑（字段多、步骤多或需分享链接时）。
```

### C4 · Switch 生效时机

```option
id: C4
kind: choice
title: Switch 生效时机
choices: immediate,with-form
```

```rule:immediate
行内/设置类 Switch 切换后立即请求并反馈；失败回滚开关状态。
```

```rule:with-form
Switch 仅作为表单字段，随「保存/提交」一并提交，不单独即时请求。
```

### C5 · 删除确认策略

```option
id: C5
kind: choice
title: 删除确认策略
choices: confirm,undoable
```

```rule:confirm
删除等破坏性操作：先二次确认，确认后再请求（与基线危险操作确认一致，本项强调项目统一用确认框而非可撤销提示）。
```

```rule:undoable
删除先乐观更新 UI，并提供可撤销提示（数秒内可 Undo）；超时或用户未撤销再真正提交（或按项目封装实现）。
```

### C6 · 路由页签缓存

```option
id: C6
kind: flag
title: 路由页签缓存
```

```rule
多页签/keep-alive：离开再进入保留列表查询态；关闭页签须丢弃该页缓存。
```

### C7 · 数字与日期输入约束

```option
id: C7
kind: flag
title: 数字与日期输入约束
```

```rule
数字字段用数字控件或限制非法字符；日期/时间按业务限制可选范围（如不可选未来日）。
```

### C8 · 新建成功置顶高亮

```option
id: C8
kind: flag
title: 新建成功置顶高亮
```

```rule
新建成功后列表回到第一页（或接口支持时置顶），并对新行做短暂高亮，便于确认已写入。
```

### C9 · 异步导出

```option
id: C9
kind: flag
title: 异步导出
```

```rule
大数据导出走异步任务：触发后有受理反馈；完成后提供下载入口或通知；禁止无反馈的长时间卡住按钮。
```

---

## D · 权限与请求层

### D1 · 统一请求错误与 401

```option
id: D1
kind: flag
title: 统一请求错误与 401
```

```rule
业务错误统一 Toast/Message；401/登录失效统一清会话并跳转登录，并发请求只触发一次跳转（防抖）。
```

### D2 · 菜单路由按钮三级权限

```option
id: D2
kind: flag
title: 菜单路由按钮三级权限
```

```rule
权限分三级：菜单可见、路由可进、按钮/行内可操作；无路由权进 403；按钮级与 B8 一致。
```

### D3 · 只读与禁用分离

```option
id: D3
kind: flag
title: 只读与禁用分离
```

```rule
只读（可聚焦查看、不可改）与禁用（不可交互）视觉与语义分开；加载中不等于成功态。
```

### D4 · 跨页勾选策略

```option
id: D4
kind: choice
title: 跨页勾选策略
choices: current-page,cross-page
```

```rule:current-page
批量操作仅针对当前页勾选；翻页清空或明确提示「仅当前页」；确认文案含数量。
```

```rule:cross-page
支持跨页勾选并保留已选集合；批量确认文案含实际已选数量，并标明为跨页已选。
```
