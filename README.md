# cheflens

冷蔵庫の中身を撮影して食材を認識し、AIがレシピを提案してくれる Flutter アプリです。

## 主な機能

### 📷 画像取得
- **カメラ撮影**: リアルタイムで冷蔵庫の写真を撮影
- **ギャラリー選択**: 既存の写真から選択

### 🔍 食材認識（Gemini Vision）

- **Gemini 2.0 Flash** のマルチモーダル機能で画像から食材を直接認識
- 画像をGeminiに渡し、日本語の食材リストをJSON形式で取得
- ホワイトリスト不要・翻訳処理不要でシンプルな実装
- 日本固有の食材（えのき、油揚げ、みょうがなど）も正確に認識

### ✅ 食材選択
- 検出された食材を一覧表示
- 食材の選択/非選択をタップで切り替え
- **手動追加機能**: カテゴリ分けされた食材リストから追加可能
  - 肉類、魚介類、野菜、果物、乳製品など7カテゴリ

### 🍳 レシピ提案
- Gemini AI (gemini-2.5-flash) を使用したレシピ提案機能
- 選択した食材からレシピ候補を3つ生成
- 候補を選択すると詳細なレシピ（材料・作り方・ポイント）をマークダウン形式で表示
- レシピ詳細のキャッシュ機能で快適な操作性

## はじめに（セットアップ）

前提:

- Flutter SDK がインストールされていること（`flutter --version` で確認）
- Xcode（iOS 開発を行う場合）や Android Studio（Android）などの開発ツール
- Google AI Studio アカウントと Gemini API の有効化（食材認識・レシピ提案の両方に使用）

クローン後の基本手順:

```bash
# リポジトリルートで
flutter pub get
```

### 環境変数の設定

Gemini API（食材認識・レシピ提案の両方に使用）を使用するため、`.env` ファイルをプロジェクトルートに作成し、API キーを設定してください。

```bash
# .env ファイルを作成
touch .env
```

`.env` ファイルに以下の内容を追加：

```env
GEMINI_API_KEY=your_gemini_api_key_here
```

**注意**: `.env` ファイルは `.gitignore` に追加済みです。API キーを誤ってコミットしないよう注意してください。

#### Gemini API のキー取得方法
1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. 「Get API Key」をクリック
3. API キーを作成してコピー
4. `.env` の `GEMINI_API_KEY` に設定

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

- レシピ提案が動作しない:
	- `.env` に `GEMINI_API_KEY` が正しく設定されているか確認してください
	- API キーの有効期限や使用制限を確認してください

## プロジェクト構成

```
lib/
├── main.dart                           # アプリのエントリーポイント
├── data/
│   ├── food_data.json                  # 食材データ（翻訳、フィルタリング設定など）
│   ├── food_translations.json          # 英日翻訳辞書
│   └── food_categories_jp.json         # 食材追加用の日本語カテゴリデータ
├── exceptions/
│   └── vision_exception.dart           # Vision API用のカスタム例外
├── models/
│   ├── detected_object.dart            # 検出された物体のモデル
│   ├── food_data_model.dart            # 食材データのモデル
│   ├── food_categories_jp_model.dart   # 日本語食材カテゴリのモデル
│   └── selected_ingredient.dart        # 選択された食材のモデル
├── screens/
│   ├── camera_screen.dart              # メイン画面（カメラ・画像選択・認識）
│   ├── result_screen.dart              # 認識結果画面（食材選択）
│   ├── ingredient_selection_dialog.dart # 食材追加ダイアログ
│   └── recipe_suggestion_screen.dart   # レシピ提案画面
└── services/
    ├── gemini_ingredient_service.dart  # 食材認識サービス（Gemini Vision）
    └── recipe_api_service.dart         # レシピ提案サービス（Gemini AI）
```

## 使用ライブラリ

- `image_picker` - カメラ・ギャラリーからの画像取得
- `http` - HTTP通信
- `flutter_dotenv` - 環境変数管理
- `image` - 画像処理
- `flutter_markdown` - マークダウン表示（レシピ詳細）
- `google_generative_ai` - Gemini AI API

## 貢献と開発者向けヒント

- `ios/Local.xcconfig.example` をリポジトリで共有しています。クローンしたら必ずコピーして自分の `ios/Local.xcconfig` を作ってください。
- 食材認識のプロンプトは `lib/services/gemini_ingredient_service.dart` の `_prompt` 定数で管理されています。認識精度を調整する場合はここを編集してください。
- 食材追加ダイアログのカテゴリは `lib/data/food_categories_jp.json` で管理されています。
