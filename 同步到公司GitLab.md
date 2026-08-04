# iOS 代码 —— 家里 ⇄ 公司 GitLab 同步手册

> 背景:公司电脑上不了 GitHub,家里又没有公司 VPN,两边直连不了。
> 解决办法:用**个人 gitlab.com 仓库当中转站**,两边都能连它。

---

## 一、三个仓库的关系(先记住这张图)

```
   家里 Mac                     gitlab.com(中转)              公司电脑
┌──────────────┐            ┌────────────────────┐        ┌──────────────┐
│ remote 名字:  │            │ gu0315/qxwebview_  │        │ remote 名字:  │
│  origin=GitHub│  ──push──▶ │        ios         │ ◀─pull─│ personal=中转 │
│  personal=中转│  ◀─pull──  │  (家和公司都能连)  │ ──push─▶│ origin=公司   │
└──────────────┘            └────────────────────┘        │       GitLab │
                                                           └──────────────┘
```

- **中转站**:`https://gitlab.com/gu0315/qxwebview_ios.git`(两台机器都叫 `personal`)
- **家里 Mac**:`origin` = GitHub(老仓库,可留着);`personal` = 中转站
- **公司电脑**:`origin` = 公司内网 `https://paas-gitlab.mychery.com/20238591/QXWebview_iOS.git`;`personal` = 中转站

> 数据流永远是:**家里 →(push)→ 中转站 →(pull)→ 公司电脑 →(push)→ 公司 GitLab**

---

## 二、日常最常用:家里改完,同步到公司

### 第 1 步 —— 在家里 Mac

```bash
cd /Users/guqianxiang/Desktop/chery/App/chery_iOS
git add -A
git commit -m "你的提交说明"
git push personal main        # 把改动推到中转站
```

### 第 2 步 —— 到公司电脑

```bash
cd "D:\Documents and Settings\20238591\桌面\chery\QXWebview_iOS"
git checkout main
git fetch personal
git merge --ff-only personal/main   # 本地 main 快进到最新
git push origin main                # 推到公司内网 GitLab
```

> ⚠️ **命令一条一条单独回车**,不要一次性粘一整块 —— PowerShell 里容易乱序执行导致失败。

做完,公司 GitLab 的 main 就和你家里一致了。

---

## 三、反向:公司电脑上改了,同步回家

### 第 1 步 —— 在公司电脑

```bash
git add -A
git commit -m "说明"
git push personal main        # 推到中转站(注意是 personal,不是 origin)
git push origin main          # 顺手也推一份到公司 GitLab
```

### 第 2 步 —— 回家 Mac

```bash
git fetch personal
git merge --ff-only personal/main
```

---

## 四、🔑 一条铁律:防止两边再次分叉

**在任何一台机器上开始改代码之前,先拉一次最新的:**

```bash
git fetch personal
git merge --ff-only personal/main
```

> 之前两边会冲突、要手动合并,就是因为各自改了又都没先拉。
> 养成「**动手前先 pull,收工后就 push**」的习惯,以后就一直是干净快进,不用再解冲突。

---

## 五、应急:万一 `--ff-only` 失败了

如果 `git merge --ff-only personal/main` 报:

```
fatal: Not possible to fast-forward, aborting.
```

说明两边又分叉了(本地有对方没有的提交,对方也有本地没有的)。改用普通合并:

```bash
git merge personal/main
```

- 没冲突 → 自动生成一个合并提交,继续 push 即可。
- 有冲突 → 打开冲突文件,搜索 `<<<<<<<` / `=======` / `>>>>>>>`,手动保留想要的内容,删掉这三行标记,然后:
  ```bash
  git add <解决了的文件>
  git commit          # 完成合并
  ```

搞不定就把报错发出来问。

---

## 六、速查

### 看当前 remote 配置

```bash
git remote -v
```

### remote 不对 / 缺失时重新配

家里 Mac:
```bash
git remote set-url personal https://gitlab.com/gu0315/qxwebview_ios.git
# 没有就把 set-url 换成 add
```

公司电脑:
```bash
git remote set-url personal https://gitlab.com/gu0315/qxwebview_ios.git
git remote set-url origin   https://paas-gitlab.mychery.com/20238591/QXWebview_iOS.git
```

### 认证(第一次 push 会要求)

- 用户名:`gu0315`
- 密码:填 **Personal Access Token**(不是登录密码),在 gitlab.com 头像 → **Preferences → Access Tokens** 生成,勾 `write_repository`。
- Windows 上嫌弹窗麻烦,可以把 token 直接写进地址(明文存在本地,注意别外泄):
  ```bash
  git remote set-url personal https://gu0315:你的TOKEN@gitlab.com/gu0315/qxwebview_ios.git
  ```

### 推 / 拉所有分支和 tag(不只是 main)

```bash
git push personal --all
git push personal --tags
```

---

## 七、其他分支(develop、ble 等)

上面都以 `main` 举例。换分支时,把命令里的 `main` 换成对应分支名即可,流程完全一样。例如同步 develop:

```bash
# 家里
git push personal develop
# 公司
git fetch personal
git checkout develop
git merge --ff-only personal/develop
git push origin develop
```
