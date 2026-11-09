# Dropbox Link Router

Slack などで Dropbox の共有リンクをクリックしたとき、ローカルの Dropbox フォルダにある該当ファイル・フォルダを Finder で開く macOS メニューバーアプリ。

## インストール

macOS 14 以降と Xcode（または Command Line Tools）が必要です。

```sh
./scripts/build-app.sh --install
open ~/Applications/"Dropbox Link Router.app"
```

## 初期設定

メニューバーのアイコンから次の 2 つを行います。

1. **Dropbox にログイン…** — 開いたウィンドウで Dropbox にログイン（Google ログイン可）。終わったら閉じて OK
2. **既定のブラウザにする** — macOS の確認ダイアログで変更を許可

このとき、それまでの既定ブラウザが「転送先ブラウザ」として記録されます。

## 使い方

| 操作 | 動作 |
|---|---|
| Dropbox の共有リンクをクリック | Finder で開く（ファイルは選択状態で表示） |
| ⌥ を押しながらクリック | ブラウザで開く |
| Dropbox 以外のリンク | 転送先ブラウザで開く |

同じ名前の候補が複数あるときはメニューから選びます。見つからないとき・削除済みのときはブラウザで開きます。

## メニュー

- **転送先ブラウザ** — Dropbox 以外のリンクを開くブラウザ
- **ログイン時に起動** — Mac 起動時に自動で立ち上げる
- **元のブラウザに戻す** — 既定ブラウザを転送先ブラウザに戻す

## アンインストール

1. メニューの **元のブラウザに戻す** を実行
2. **ログイン時に起動** をオフにして終了
3. `~/Applications/Dropbox Link Router.app` を削除

## うまく開かないとき

- まず **Dropbox にログイン…** からログインし直す
- ログインし直しても直らなければ、ログで受信した URL と判定結果を確認する

```sh
log show --last 10m --predicate 'subsystem == "com.dkakimi.DropboxLinkRouter"' --style compact
```
