# BlockChain Library Suite

## blocks について
blocks は中本智さんの論文に基づいて開発されたiOSライブラリです。
あなたのアプリにブロックチェーンを導入できます。

いろんな目的に使用できますが、仮想通貨取引所で交換可能な暗号資産として使用することを禁止します。

このブロックチェーン・ライブラリが特徴的なのは、政府・公共・民間の社会システムにおける活動をあらかじめ組み込まれていることです。（出生証明、住民票、身元保証など）

添付の overlayNetwork ライブラリに依存します。

## overlayNetwork について
overlayNetwork は、Peer-to-Peerオーバーレイ・ネットワーク通信システムです。
MIT Laboratoryの分散ハッシュテーブルの実装である Chord 論文に基づいて開発されたものです。

他のライブラリに依存しません。

## Testy について
Testy は住民基本台帳カードの代替として開発されています。

blocksライブラリとoverlayNetworkライブラリの使用参考例として作成されたものです。

## download

blocks - ブロックチェーン・ライブラリα版 
[ダウンロード](https://github.com/webbananaunite/blocks) 
https://github.com/webbananaunite/blocks
 
overlayNetwork - peer-to-peer分散ハッシュテーブル通信ライブラリα版 
[ダウンロード](https://github.com/webbananaunite/overlayNetwork) 
https://github.com/webbananaunite/overlayNetwork
 
Testy - 住民基本台帳アプリα版 
[ダウンロード](https://github.com/webbananaunite/Testy) 
https://github.com/webbananaunite/Testy

## How to Use
1) ブロックチェーン・ライブラリ・スイート（３リポジトリ）をダウンロードし、あなたのアプリと同じディレクトリに保存します。  
2) XcodeでTestyプロジェクトまたはあなたのアプリを開きます。  
3) blocksプロジェクトのFrameworks and LibrariesにoverlayNetworkがあることを確認します。  
4) TestyプロジェクトまたはあなたのアプリのプロジェクトのFrameworks and LibrariesにoverlayNetwork, blocksがあることを確認します。  
5) overlayNetwork/Domain/Dht.swift 227行目にある{bootnodes}をあなたのローカルネットワークで最初に起動するデバイスのIPアドレスに変更します。  
6) Xcodeでビルド、デバイスやシミュレータへのインストールを行います。  
7) アプリを起動し、"生体認証"ボタンをタップします。  
8) DHCテーブルの初期化が完了するまで8分ほど待ちます。  

## ライセンス
blocks & overlayNetwork & Testy は MIT Licenseで公開されています。  

無料で、あなたのアプリに組み込んで利用できます。  
いろんな目的のアプリに組み込み可能ですが、仮想通貨取引所で交換可能な暗号資産として使用することを禁止します。

## 禁止事項
仮想通貨取引所で交換可能な暗号資産として使用することを禁止します。

## その他説明
### 言語:  
- SwiftUI (Protocol Oriented) 
- C++ (Metal) 
- objc (DNS resolv)

### サードパーティライブラリの使用
使用していません。しかし、他の著作物を含んでいます。
- QuadKey - Microsoft Corporation  
- SHA-512 - Aaron D. Gifford

### プログラミングアーキテクチャ  
around DDD, Onion (Protocol Oriented)

### バイトオーダー  
- Distributed Hash Table (Finger table) address  
Little Endian

- nonce  
Little Endian

### cpu, gpu
nonce の計算はcpuもしくはgpuを選択可能です。

## ステータス
Alpha  

現在、すべての機能は実装されていません。
- 例. overlayNetwork の DHT ネットワークから離脱したり、また戻ったりする場合への対応。  

2024年5月に、すべての機能を実装した版をリリース予定です。  

Peer-to-Peerオーバーレイ・ネットワークと、ブロックチェーンでの社会基盤構築に賛同していただける方、ボランティアになりますが、共に開発に貢献してくれる方やテストに参加してくれる方を募っています。  

ただし、仮想通貨取引所関係の方はお断りさせていただいておりますことをご了承ください。  

ご連絡をお待ちしています。  

一緒に楽しみましょう！
