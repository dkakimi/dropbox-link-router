# Dropbox Link Router

Slack などで Dropbox の共有リンクをクリックしたとき、ローカルの Dropbox フォルダにある該当ファイル・フォルダを Finder で開く macOS メニューバーアプリ。

- 対応 OS: macOS 14 (Sonoma) 以降
- Apple Silicon / Intel の両方に対応
- Mac に Dropbox デスクトップアプリが入っていて、同期フォルダ（`~/Library/CloudStorage/Dropbox*`）があること

## インストール

次のどちらかの方法でインストールします。

| 方法 | 向いている人 |
|---|---|
| [方法 1: ビルド済みの .app をダウンロード](#方法-1-ビルド済みの-app-をダウンロード) | すぐに使いたい人 |
| [方法 2: ソースコードからビルド](#方法-2-ソースコードからビルド) | 最新版を使いたい人、中身を確認してから使いたい人 |

### 方法 1: ビルド済みの .app をダウンロード

1. [Releases](https://github.com/dkakimi/dropbox-link-router/releases/latest) から `Dropbox-Link-Router.zip` をダウンロードする
2. ダウンロードした zip をダブルクリックして展開する
3. 出てきた `Dropbox Link Router.app` を「アプリケーション」フォルダ（`/Applications` または `~/Applications`）に移動する
4. 初回だけ、次の「初回起動時の警告について」の手順で開く

#### 初回起動時の警告について

このアプリは Apple の正式な署名（公証）をしていないため、そのままダブルクリックすると
「“Dropbox Link Router”は開いていません」「開発元を検証できません」などの警告が出て開けません。
次のどちらかの方法で開いてください（2 回目以降は普通に開けます）。

**A. システム設定から許可する**

1. 一度アプリをダブルクリックし、警告が出たら「完了」（または「キャンセル」）で閉じる
2. **システム設定 → プライバシーとセキュリティ** を開く
3. 下の方にある「“Dropbox Link Router”は Mac を保護するためにブロックされました」の横の **このまま開く** をクリック
4. パスワード（または Touch ID）で確認し、もう一度 **このまま開く** をクリック

**B. ターミナルで警告を解除する**

ターミナルで次を実行してから、アプリをダブルクリックします（アプリを置いた場所に合わせてパスを変えてください）。

```sh
xattr -dr com.apple.quarantine "/Applications/Dropbox Link Router.app"
```

### 方法 2: ソースコードからビルド

#### 準備

ビルドには Xcode か Command Line Tools が必要です。ターミナルで次を実行して、パスが表示されれば準備済みです。

```sh
xcode-select -p
```

エラーが出る場合は、次を実行して表示されるダイアログから Command Line Tools をインストールしてください（数分〜十数分かかります）。

```sh
xcode-select --install
```

#### ビルドとインストール

ターミナルで次を順に実行します。

```sh
# 1. ソースコードをダウンロード（好きな場所で OK）
git clone https://github.com/dkakimi/dropbox-link-router.git

# 2. ダウンロードしたフォルダに移動
cd dropbox-link-router

# 3. ビルドして ~/Applications にインストール（初回は 1〜2 分かかります）
./scripts/build-app.sh --install

# 4. 起動
open ~/Applications/"Dropbox Link Router.app"
```

`git` が使えない場合は、GitHub のページの **Code → Download ZIP** でダウンロード・展開し、そのフォルダの中で 3 以降を実行しても同じです。

自分の Mac でビルドしたアプリは、方法 1 のような起動時の警告は出ません。

#### 最新版への更新

```sh
cd dropbox-link-router
git pull
./scripts/build-app.sh --install
open ~/Applications/"Dropbox Link Router.app"
```

アプリが起動中の場合は、先にメニューバーのアイコン → **終了** で終了しておいてください。

## 初期設定

起動するとメニューバーにフォルダのアイコンが表示されます。アイコンをクリックして、次の 2 つを行います。

1. **Dropbox にログイン…** — 開いたウィンドウで Dropbox にログイン（Google ログイン可）。終わったらウィンドウを閉じて OK
2. **既定のブラウザにする** — macOS の確認ダイアログで変更を許可

このとき、それまでの既定ブラウザが「転送先ブラウザ」として記録されます。
初回起動時に「ログイン時に起動」が自動でオンになり、Mac の起動時に自動で立ち上がります。

## 使い方

| 操作 | 動作 |
|---|---|
| Dropbox の共有リンクをクリック | Finder で開く（ファイルは選択状態で表示） |
| ⌥ (option) を押しながらクリック | ブラウザで開く |
| Dropbox 以外のリンク | 転送先ブラウザで開く |

同じ名前の候補が複数あるときはメニューから選びます。見つからないとき・削除済みのときはブラウザで開きます。

## メニュー

- **転送先ブラウザ** — Dropbox 以外のリンクを開くブラウザ
- **ログイン時に起動** — Mac 起動時に自動で立ち上げる
- **元のブラウザに戻す** — 既定ブラウザを転送先ブラウザに戻す

## アンインストール

1. メニューの **元のブラウザに戻す** を実行
2. **ログイン時に起動** をオフにして **終了**
3. `Dropbox Link Router.app` をゴミ箱に入れる

## うまく開かないとき

- まず **Dropbox にログイン…** からログインし直す
- ログインし直しても直らなければ、ログで受信した URL と判定結果を確認する

```sh
log show --last 10m --predicate 'subsystem == "com.dkakimi.DropboxLinkRouter"' --style compact
```
