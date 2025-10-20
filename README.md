# cheflens

冷蔵庫の中身を撮影して食材を認識し、献立を提案する Flutter アプリのサンプルリポジトリです。

## はじめに（セットアップ）

前提:

- Flutter SDK がインストールされていること（`flutter --version` で確認）
- Xcode（iOS 開発を行う場合）や Android Studio（Android）などの開発ツール

クローン後の基本手順:

```bash
# リポジトリルートで
flutter pub get
```

エミュレータ／シミュレータで実行:

```bash
# 利用可能デバイス一覧を確認
flutter devices

# シミュレータ名や deviceId で実行（例）
flutter run -d "iPhone SE (3rd generation)"
```

実機での実行（iOS）はコード署名（Signing）が必要です。Xcode で Team を設定し、プロビジョニングの準備を行ってください。

## iOS ローカル設定（重要）

このプロジェクトでは、個人の Apple Team ID やプロビジョニング情報を誤ってコミットしないように
ローカル専用の `ios/Local.xcconfig` を使う運用にしています。手順は以下の通りです。

1. テンプレートをコピーしてローカルファイルを作成:

```bash
cp ios/Local.xcconfig.example ios/Local.xcconfig
```

2. `ios/Local.xcconfig` を開き、必要な行のコメント（`//`）を外して自分の値を設定します:

```text
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
BUNDLE_IDENTIFIER = com.yourname.cheflens
PROVISIONING_PROFILE_SPECIFIER = "Your Provisioning Profile"
```

3. `ios/Local.xcconfig` は `.gitignore` に追加済みです。絶対にコミットしないでください。

4. Xcode を再起動、またはプロジェクトをクリーンして設定を反映します。

補足:

- Xcode 側で署名設定を触ると `ios/Runner.xcodeproj/project.pbxproj` にローカル差分が書かれることがあります。
	コミット前に `git status` を確認し、余計な差分がある場合は `git restore ios/Runner.xcodeproj/project.pbxproj` で戻してください。

## よくあるトラブルと対処

- iOS シミュレータでアプリを起動できない（ランタイムが足りない）:
	- Xcode → Settings → Components で必要なシミュレータランタイムをインストール

- 実機にインストールしたがアプリが起動しない／すぐ落ちる:
	- `Info.plist` にカメラや写真ライブラリの使用説明（`NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`）が必要です
	- 署名エラーが出る場合は Xcode の Signing & Capabilities で Team を設定し、自動プロビジョニングを試してください

- カメラ機能のテストについて:
	- シミュレータは実機のカメラ入力を提供しないため、`xcrun simctl addmedia booted /path/to/photo.jpg` で画像を追加してギャラリーベースで動作確認してください

## 貢献と開発者向けヒント

- `ios/Local.xcconfig.example` をリポジトリで共有しています。クローンしたら必ずコピーして自分の `ios/Local.xcconfig` を作ってください。