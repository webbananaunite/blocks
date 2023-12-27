//
//  Blocks.swift
//  blocks
//
//  Created by よういち on 2020/05/27.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
// 設計思想をここに書いている

/*
 [モチベーション]
 ・ブロックチェーンはなぜ導入が進まない？
 ブロックチェーンに何かを保存するたびに経費がかかる　bitcoin, etherium
 (既存BC)                    (新BC)
 -アカウント作成
 0BC                        50BC
 -本人確認
 機能なし                    身元保証人（Taker）と転入先アプリケーションOwner(Fact)が本人確認する *ペナルティあり *BookerがBlockにペナルティtransactionを付加　→合意プロセス
 -振り込みに使いたい
 交換所で円とBCを交換        交換必要なし
 -増える方法
 マイニング（専門業者）    新規アカウント作成(Birth)、身元保証(Taker)、マイニング(Booker)、データ保存(Library)
 -ブロックチェーンを利用するアプリ（サービス）
 複数ある                    複数ある

 
 [設計思想]
 * : アプリケーションでサブクラス実装する
 ・Birth、MoveIn時の本人確認は、利用時の社会において的確なもので確認する
 ・Taker、Birth、BasicIncomeによってのみBKが増える
 ・Booker、Libraryへの報酬はTransaction手数料のみとする
 ・アプリケーションに参加(MoveIn)しないと何もできない
 ・MoveInすると個人情報（住所氏名など）はアプリケーションOwnerに開示され存在確認チェックされる
 ・Factするのは結構高額に設定する（安易にアプリケーション登録できないように）
 
 ・Booker(ブッカー)：ブロックをブロックチェーンに含める人
 ・Library(ライブラリー)：Bookを保存してくれる人
 ・ブッカーとライブラリーに報酬がいくようにする
 ・ペナルティにより所持BKがマイナスになったとき利用停止措置となる（Taker、Book、Mail）
 
 ・transactionId: prefix(ASCII 2Byte) + uniqueString(256Byte)     ex. ABeic3aoc93kl93HOle82DKL+#(cld83
 ・メール機能あり
 ・利用するには Person - Birthする必要がある
    Birth時に一定額を給付する（50BK）50ブッカー
    x Takerにも給付金あり
        x 不正Birthが認められるとペナルティで反則金として没収される（-100BK）-100ブッカー
 ・トランザクション費用
    1トランザクション／1ブッカー
 
 ・実在証明
    身元保証書（Taker身元保証人が署名した３情報）があること
    身元保証書の記載内容（氏名、住所等）でCached Blocksを検索して重複がないこと
        住所は広めの範囲（文字数を少なくして前方一致）のQuadKeyで検索する
 
    x Takerが秘密鍵で「住所・氏名・生年月日・社会ID１・社会ID２」を署名（Hash->ECDSA256->Base64）した文字列
 
 ・社会ID  甲乙の２つのID
    （甲種）民間機関発行の相互やりとり可能なID
    電話番号（SMS可能なもの）
    携帯電話に紐づくプロバイダID（Google｜Apple｜docomo）
    Eメールアドレス
 
    （乙種）政府機関発行の身元保証書
    出生証明書（医院発行）
    健康保険証番号
    マイナンバー
    免許証番号
 x 最終学歴の教育機関名（中途退学を含む）

    x（丙種）人体的特徴によるID
    x 指紋画像をHash＆暗号した文字列
    x 虹彩画像
    x 手のひら静脈画像
 

    x＜本人確認方法＞
    1) Birth住所の確認：GPS ＋ IP＜都道府県＞ ＋（基地局|wifi）＋高度計＜階数＞＋窓外の写真 ←住民票の代わり
    2) 本人の確認：ポートレート写真　＋
        出生からの履歴　出生場所、小学校、中学校、高校、大学、勤務先、性別
    x3) 最近一定期間（１ヶ月）の行動履歴    GPS履歴、スマホOSメーカアプリで収集した行動履歴
    4) 2者以上の行動証明
        例）Amazon(AuthorizedRetailer)からの購入商品をコンビニで受け取った
            コンビニ店の受け取り証明
            Amazonの配送証明
        スーパー(AuthorizedRetailer)で買い物をした
            スーパーの販売証明
            ApplePayの支払い証明
 
 
 ・Birthの流れ
    Birth　社会への参加）{18歳}?になったら本人が行う？
    or
    出生時に親権者が行う
    ↓
    5つの情報を入力する
        氏名(UTF8、スペースタブ不使用)
        生年月日(yyyymmdd)
        デバイス電話番号（数字のみ、国番号(ex.81)＋10桁（70文字のSMS可能なもの）←出生時に番号のみ予約する?
        出生地QuadKey（病院など）
        現在地QuadKey
        社会ID乙種
    ↓
    1 Taker の署名をもらう
        TakerはBornPlaceQuadKeyが一定の近さでなければならない
        Takerの署名、Taker公開鍵(後見人として)
        Takerは{1.5}人までのBirth署名ができる
    ↓
    x デバイス電話番号には、ノンスを付加（UTF8、20文字以上1000文字まで、情報ごとに別、情報ごとに1箇所）例：819{hop998arzhcoi}011110000
    ↓
    スペースタブ-削除
    ↓
    各情報ごとにハッシュ
    ↓
    transactionに書く
    ↓
    Publish Transaction
    ↓
    Booker がproof of workするときに重複チェックする (Publish Block
    ↓
    BlockをBookに Libraryするときも重複チェックする
 
    ＜重複チェック方法＞これをpublish block受信時に入れる
    cf.実在証明
    身元保証書Transaction（Taker身元保証人が署名した３情報）があること
    身元保証書の記載内容（氏名、住所等）でCached Blocksを検索して重複がないこと
        住所は広めの範囲（文字数を少なくして前方一致）のQuadKeyで検索する

    氏名and生年月日andデバイス電話番号でCached Blocksを検索する
    Takerの行動履歴確認
    Takerの署名が正しいか
    Takerは{1.5}人までのBirth署名ができる（これについては、blocksの普及速度に関係する。）
    ３等身以内のTakerは協力できない。

 
 ・二重に給付金はもらえるが、使えないようにする
    taker先祖の枝は遡れる
    ↓
    スーパーに MoveInするときに詳細な本人確認する
    免許証、マイナカード、保健証で本人確認。
        オンラインで証明書の写真をMail送信
    ↓
    他店のMoveIn transactionがあるかチェック
        氏名、住所でCached blocksを検索して公開鍵が同じかチェックする　→公開鍵が違うのはNG（１人で2つのアカウントを利用の不正利用）
    ↓
    購入
    ↓
    商品受け取る
 
 
 ・不正利用時
    １人で2つのアカウントを利用の場合は、長いチェーン（多く利用されている方）のアカウント以外は遡って無かったことにする（Balanceにカウントしない）
 
 
 ・AuthorizedRetailer
    Retailerのウェブで公開鍵を公開する
 ・Taker    身元保証人
    身元が不正の場合大きなペナルティあり
 ・UnMover   政府の代替
    早い者勝ちで一定人数（15人）をBirthする  初期だけ
    不正があったりしたら、入れ替える
        Birthが不正（存在しない人）の判断方法　←Booker, Libraryするときにシステムでチェックできるのか？　できない
    ↓
    自分の知り合いのTakerとなっていく
    ↓
    存在しない人のTakerとなった場合はBirth給付金の１０倍BKをペナルティとして支払う　Taker遡及はしない
 
 

 [検討事項]
 ok Personの実在性をどうやって確認するか？　Oracle？
    ok 免許証などの本人確認書類の画像を登録する？
 ok 報酬は何で付与するか？
 ok 本人存在確認方法
    Taker 時のペナルティによる保証
    MoveIn 時に、Fact(アプリケーションOwner)には個人情報が開示されるのでFactが実在確認を行う
 ok 現在時間取得方法
    x 時刻認証局
    x 平均タイムスタンプ
    中央値タイムスタンプ（Bookerが付与する）を採用する
        Blockに含めるTransactionのタイムスタンプ(Transaction Time)の中央値をそのBlockのタイムスタンプ(Block Time)とする

 [基本クラス＆関数]    ライブラリ
 Transaction    トランザクション
    *New         新規ブロック生成する（金銭の送金）
        *1BK必要
        Json    トランザクションの内容
            ex. { transactionId: "AB" + uniqueString, date:yyyymmdd hhmmss.ss, type: xx, maker: xxx, to: xxx, amount: xxx, unit: xxx }
 
    Publish     Transactionを発行する
 
    *Validate    Blockにブッキングするときにトランザクションの有効性をチェックする
        makerのamountが送金額以上かチェック
        makerがアプリケーション利用者か？
            利用者登録必要か？
        Block内Transactionの妥当性
        Book時には署名の確認のみ　←アカウントの保証はできる
        ３親等以内への（BirthからTaker、TakerからBirth）送金は無効とする
 
    Sign        署名する
        Hash
        Base64
        Encrypt(ECDSA 256) makerの公開鍵で暗号
 
    Fact(Sub class)        アプリケーションを登録する（ユニークトランザクション）
        New(Transaction - Newのサブクラス)
            全てのプロパティがユニークであることが保証される
            *500BK必要
            Json    トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, prefix: "AB", ownerPublicKey: xxx }
        FactしたPersonには、MoveInの通知が届く

    Person(Transaction Sub class)
        BasicIncome 定期給付金
            すべてのPersonに年１回50BK
            毎月自分からTransaction発行して要求する（アプリのボタンをタップして
 
        Birth       出生届
            自然人が一人１回だけBirthできる
            １８歳以上の成人のみBirth＆Transactionできる（未成年は利用できない）
            自分自身をBirthする
                身元保証人(Taker)１名の個人情報への署名が必要
            x TakerにはBirthした人の公開鍵（アドレス）がわからない
 
            Json     トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, to: xxx, amount: xxx, unit: xxx, rentTime: yyyymmdd hhmm }
 
            x ＜Birthの流れ＞　＊上に記載した
            （Taker）BirthできることをSNSで周知する
                Birth手順も周知する
            ↓
            （Birth）SMS、Eメール、チャットでBirthに添付する実在証明を得るために、Takerに個人情報を送付する
            ↓
            （Taker）秘密鍵で個人情報「住所・氏名・生年月日・電話番号」に署名（Hash->ECDSA256->Base64）して返信する
            ↓
            （Birth）Person - Birthする

        MoveIn      アプリケーションへの転入届
            Json    トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, body: ID personの公開鍵で暗号した本人のデータ（名前、住所、写真、電話番号、スマホID） }
            *本人存在確認を行う
                MoveIn 時に、Fact(アプリケーションOwner)には個人情報が開示されるのでFactが実在確認を行う
            アプリケーション登録したオーナーの公開鍵は公開されている
            ↓
            （利用者）Birth時に個人情報（Hash&秘密鍵でEncrypt&Base64）をトランザクションに登録
            ↓
            （利用者）利用者の公開鍵をアプリケーションOwnerにOwnerの公開鍵で暗号してMailする
            ↓
            （Owner）Person - Validateする
            ↓
            （Owner）Person - Authorizeする

        MoveOut     アプリケーションからの転出届
            Json    トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, body: ID personの公開鍵で暗号した本人確認データ（写真） }
        Validate    利用者の本人確認をする
            Birth時の個人情報を利用者からMailされた公開鍵で復号してチェックする
            [チェック方法]
            （Oracle）SMSなどでパスコードを送る
            ↓
            （Oracle）システムでチェック
            ↓
            チェック結果が存在しないあるいは不正がある場合
                
        Authorize   Fact OwnerがMoveInを許可する
 
    Mail(Transaction Sub class)
        Send           特定の相手に通知する
        Json    トランザクションの内容
            ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, to: ID, body: ID personの公開鍵で暗号したデータ（文、数値、写真、動画） }

 Block          ブロック
    Genesis     最初のブロック

    New         新規ブロック生成する
        Json    内容
            ex. { blockId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, transactions: [transactions] }
    Add         Transactionを追加する
        署名確認、残高確認のみ行う
    FetchTime(UTC)  ブロック生成時間
    Sign        署名する
        Hash
        Base64
        Encrypt(ECDSA 256)
    Validate    有効性チェックする
        Blockの妥当性

 Book(Block配列)         ブロックの配列(一方向リスト構造)
    Proof of work
        問題から正解を得た最初の人だけがそのタイミングでBookできる
        Bookタイミング：５分ごと
    Extract（抽出）
        一連のBookの中からあるアプリケーションのトランザクションを抽出する
    Chain       ブロックをつなげる
    Library
        ブックをコンピュータに保存する
 
 Node           通信ノード／ウォレット
    BootNode    近隣ノードを探すための最初のノード（AWSでノードをひとつ立てる）
    Address(Public key)
    Validate    有効性チェックする

 
 [応用クラス]    アプリケーション
 
 [銀行]   電子マネーウォレットアプリ
 Wallet
    Balance     残高表示
    SendMoney   送金
        Json        トランザクションの内容
            ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, to: xxx, amount: xxx, unit: xxx }

 [レンタル]
 User           アカウント情報／ユーザー
    SystemID
    Name
    Where(Address)
    Registered Date
 
 Rent           レンタルする
    Json        トランザクションの内容
        ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, to: xxx, amount: xxx, unit: xxx, rentTime: yyyymmdd hhmm }
    基本クラス - Transaction - Newをinvoke
 
 Pay            料金支払う
    Json        トランザクションの内容
        ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, referencedTransactionId: xxx }
    基本クラス - Transaction - Newをinvoke

 [住民基本台帳]   公共システム
 Person（Inheritance登録内容追加）         アカウント情報／ユーザー
    SystemID
    Name
    Where(Address)
    Registered Date
    前の住所
    世帯主
 
 Birth(Inheritance登録内容追加)          出生届
    Json        トランザクションの内容
        ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, to: xxx, amount: xxx, unit: xxx, rentTime: yyyymmdd hhmm }

 MoveIn(Inheritance登録内容追加)         転入届
    Json
 
 MoveOut(Inheritance登録内容追加)        転出届
 

 
 
 

 */
