azoo-key-skkserv
===

[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)を変換に利用するskkservです。  
AzooKeyKanaKanjiConverterから参照される、ニューラルかな漢字変換システム「Zenzai」で利用するモデルは[zenz-v1](https://huggingface.co/Miwa-Keita/zenz-v1)を利用させていただいています。

zenz-v1はKeita Miwa ([𝕏](https://x.com/miwa_ensan))さんによって開発され、[CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/deed.ja)で提供されています。

Linux環境向けのバイナリには[llama.cpp](https://github.com/ggml-org/llama.cpp)の[Shared Object](https://github.com/ggml-org/llama.cpp/releases/tag/b4846)を同梱させていただいております。  
かつ `RUNPATH` を `$ORIGIN` にpatchさせていただいております。

## azoo-key-skkservについて

macOSで動作する、受け取った読みをAzooKeyKanaKanjiConverterで漢字変換し、候補を辞書として返すskkservです。  
これにより例えば:

- `配達業者` などそれぞれの熟語は辞書に入っているけれど、繋がったものは登録されていないケースでも候補を表示できます。
- 送り仮名が不明瞭であったりする際、送り仮名ごと入力しても候補が表示されます。
- SKKの流儀とは反しそうですが、Zenzaiの強力な変換力により、長文をそのまま変換することも可能です。
    - SKKの仕様上ユーザー辞書にそのまま登録されてしまうと思うので、その点はご注意ください。
 
### 動作イメージ

https://github.com/user-attachments/assets/614f87b9-062a-4710-92e2-f275eb80703f

## インストール

[Releases](https://github.com/gitusp/azoo-key-skkserv/releases)よりご自身のarchに対応したパッケージをダウンロードしてください。  
その後、解凍されたパッケージをお好きなところに配置してください。

macOSは `azooKey skkserv.app` 、それ以外のarchはパッケージ内の `azoo-key-skkserv` が実行ファイルです。

### ダイナミックライブラリについて

こちらのLinux検証環境だと `libgomp.so.1` が見つからないエラーが出ました。  
もし見つからない場合は、以下のようなコマンドでインストールお願いします。

```sh
apt install libgomp1
```

### GUIについて

macOS版はGUIアプリケーションの提供もございます。([mtgto](https://github.com/mtgto)さんありがとうございます！)  
[Releases](https://github.com/gitusp/azoo-key-skkserv/releases)に `.dmg` ファイルも置いてあるので、そちらからインストールしてください。

macSKKから使用する場合にはIncoming CharsetにEUC-JP、macSKKの応答エンコーディングにUTF-8を指定してください。

## 使い方

```sh
azoo-key-skkserv [--port <port-number>] [--incoming-charset <charset>] [--inference-limit <limit>] [--help] [--version]
```

_EUC-JP範囲外の候補があるため `--outgoing-charset` オプションはなく、サーバーからは常にUTF-8で返します。_

### バックグラウンド実行

私はmacOSのAutomatorで以下のshellを実行するアプリケーションを作成しています。

```sh
nohup ~/opt/azoo-key-skkserv/azoo-key-skkserv --incoming-charset EUC-JP >&/dev/null &
```

作成したアプリケーションはログイン項目に登録しておき、自動的にサーバーが立ち上がるようにしています。

## 仕様

skkservの標準に準拠しているつもりです。  
入力の1文字目を `opcode` とし、それ以降を `operand` とした場合:

| opcode | operand  | 説明             | 出力                                              |
|--------|----------|------------------|---------------------------------------------------|
| 0      | なし     | コネクション破棄 | なし                                              |
| 1      | 見出し語 | 辞書要求         | 候補がある時は `1/{候補1}/{候補2}/.../{候補n}/\n` |
| 2      | なし     | サーバー情報要求 | `azoo-key-skkserve/{バージョン} `                 |
| 3      | なし     | ホスト情報要求   | `{ホスト名}/127.0.0.1:{ポート}/ `                 |
| 4      | 見出し語 | 補完要求         | `4\n` (未実装)                                    |

## 開発

```sh
swift run azoo-key-skkserv
```

## 動作検証環境

### macOS(Apple silicon)

[macSKK](https://github.com/mtgto/macSKK)と結合して動作確認

### macOS(Intel)

動作未確認

### Ubuntu(arm64)

macOS上で動作するDockerにて、netcatで動作確認

### Ubuntu(amd64)

一応コンパイルできていそうなのですが、エミュレータだとうまく実行できていません。

## 免責

まだまだ使いながら調整したりしてる段階なので、不具合や不安定なところがあるかと思います。  
もし何かございましたら、Issueでご報告いただいたりPRを投げていただけると大変助かります🙇
