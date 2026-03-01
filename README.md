# 九星気学 (Nine Star Ki) アプリケーション

このプロジェクトは九星気学に基づいた占いアプリケーションです。ユーザーの生年月日と時間から本命星、月命星、日命星、時命星を計算し、その特性を表示します。

## 機能

- 生年月日と時間に基づいた九星気学の計算
- 本命星、月命星、日命星、時命星の表示
- 各星の特性（五行、方位、色など）の詳細表示
- ユーザーフレンドリーなインターフェース

## 技術スタック

### バックエンド
- Python
- SQLAlchemy
- FastAPI

### フロントエンド
- Next.js
- TypeScript
- Mantine UI

### インフラ
- Docker
- Docker Compose

## セットアップ

### 前提条件
- Docker と Docker Compose がインストールされていること

### 実行手順
1. リポジトリをクローン
```
git clone https://github.com/yourusername/ninestarki.git
cd ninestarki
```

2. Docker Composeでアプリケーションを起動
```
docker-compose up -d
```

3. ブラウザで以下のURLにアクセス
```
http://localhost:3000
```

## 배포 (デプロイ)

프로덕션 서버(ConoHa)에 배포할 때는 `deploy.sh` 스크립트를 사용합니다:

```bash
./deploy.sh
```

> 📖 서버 필수 파일, 환경변수 설정, 트러블슈팅 등 상세한 내용은 [프로덕션 배포 가이드](docs/deployment-guide.md)를 참조하세요.

## 開発

### バックエンド開発
```
cd backend
# 開発用コマンド
```

### フロントエンド開発
```
cd frontend
# 開発用コマンド
```

## テスト

```bash
make test              # 全テスト実行（単体 + 統合）
make test-unit         # 単体テストのみ（DB 不要）
make test-integration  # 統合テストのみ（DB + バックエンド必須）
make db-seed           # DB を完全リセット＆再投入
```

- **CI:** `main` への Push / PR で単体テストが自動実行されます。
- **統合テスト:** GitHub Actions の "Integration Tests (Manual)" ワークフローから手動実行できます。

> 📖 テスト分離の経緯、データシーディングパイプライン、トラブルシューティングの詳細は [CI テスト アーキテクチャ](docs/ci-test-architecture.md) を参照してください。

## ライセンス

このプロジェクトは [MIT ライセンス](LICENSE) の下で公開されています。

## データベース構造

- `stars`: 九星の基本情報
- `solar_starts`: 立春の日時データ（1955-2025年）
- `solar_terms`: 節入りの日時データ（1955-2025年）
- `nine_star_chart`: 九星盤データ（年盤、月盤、日盤、時盤）
- `compatibility`: 九星間の相性データ

## API

### 九星計算 API

```
POST /api/nine-star/calculate
```

リクエスト例:
```json
{
  "birth_datetime": "1980-02-04 15:30"
}
```

レスポンス例:
```json
{
  "birth_datetime": "1980-02-04 15:30",
  "main_star": {
    "name": "一白水星",
    "year": 1979,
    "risshun_datetime": "1980-02-04 01:10:00",
    "details": {
      "number": 1,
      "name_jp": "一白水星",
      "name_en": "White Water Star",
      "element": "水",
      "direction": "北",
      "color": "白",
      "personality": "知性的で冷静、合理的な判断ができる。独立心が強く、自分の意見をしっかり持っている。",
      "strength": "分析力、知性、独創性",
      "weakness": "感情表現が苦手、孤独になりがち",
      "career": "研究者、学者、作家、プログラマー",
      "health": "腎臓、膀胱に注意"
    }
  },
  "month_star": {
    "name": "四緑木星",
    "year": 1980,
    "month": 2,
    "solar_term_datetime": "1980-02-04 01:10:00",
    "details": {
      "number": 4,
      "name_jp": "四緑木星",
      "name_en": "Green Wood Star",
      "element": "木",
      "direction": "東南",
      "color": "緑",
      "personality": "温和で協調性があり、人との関わりを大切にする。包容力があり、人の気持ちを理解するのが上手。",
      "strength": "協調性、包容力、バランス感覚",
      "weakness": "優柔不断、他人に流されやすい",
      "career": "医療、カウンセラー、教師",
      "health": "肝臓、胆のうに注意"
    }
  },
  "day_star": "九紫火星",
  "hour_star": "六白金星"
}
```

### 相性占い API

```
POST /api/nine-star/compatibility
```

リクエスト例:
```json
{
  "star1": 1,
  "star2": 4
}
```

レスポンス例:
```json
{
  "star1": 1,
  "star2": 4,
  "compatibility_score": 5,
  "description": "水と木の相性は最高。一白水星が四緑木星の成長を助け、バランスの取れた関係に。"
}
```

## 作者

Your Name 

## データベース接続情報について

このプロジェクトでは、すべてのデータベース操作で統一されたユーザー情報を使用します。

### デフォルトの接続情報

- ホスト: `mysql`
- ユーザー: `ninestarki`
- パスワード: `ninestarki_password`
- データベース: `ninestarki`
- ポート: `3306`

これらの設定は環境変数で上書きすることができます。

### 環境変数

以下の環境変数を設定することで、接続情報をカスタマイズできます：

- `DB_HOST` - データベースホスト名（デフォルト: mysql）
- `DB_USER` - データベースユーザー名（デフォルト: ninestarki）
- `DB_NAME` - データベース名（デフォルト: ninestarki）
- `DB_PORT` - データベースポート（デフォルト: 3306）
- `DATABASE_URL` - 接続文字列（設定されている場合、個別の環境変数より優先されます）

## Docker環境

Docker環境では、`docker-compose.yml`によって自動的にMySQLサーバーとユーザーが設定されます。
`mysql/init/001_create_users.sql`によってユーザー権限が付与されます。

## スーパーユーザーの作成

データベース初期化時に、`ninestarki@example.com`/`ninestarki_password`というスーパーユーザーが自動的に作成されます。
このユーザー情報は以下の環境変数で変更できます：

- `SUPERUSER_EMAIL` - スーパーユーザーのメールアドレス
- `SUPERUSER_PASSWORD` - スーパーユーザーのパスワード

## CSVデータのロード

CSVファイルからデータをロードする際、FILE権限が必要なLOAD DATA INFILE構文を使用します。
この権限は`ninestarki`ユーザーに付与されています。LOAD DATA INFILEが失敗した場合は、
代替方法として通常のINSERT文を使用してデータをロードします。 

## トラブルシューティング (Troubleshooting)

### Docker環境での pytest `PermissionError` (Errno 13)
Dockerコンテナ(`backend-test`)内で `make test` または `pytest` を実行した際、`/app/logs` や `/app/.pytest_cache` への書き込み権限エラー（`PermissionError: [Errno 13] Permission denied`）が発生する場合があります。

**原因:**
ホスト側のディレクトリをコンテナ内の `/app` にマウントしている環境下において、コンテナ内を実行しているユーザー（`appuser`など）が、ホスト側ファイルの権限設定によりキャッシュやログディレクトリを作成できないために発生します。またGitHub Actions環境では、Gitの仕様上 `.gitignore` に含まれた対象ディレクトリ(`logs`, `.pytest_cache`)自体が存在しないためエラーになります。

**解決策:**
1. **コンテナをroot権限で実行する (ローカル環境)**
   `docker-compose.dev.yml` の `backend-test` サービスに `user: root` を指定します。MacやWindows上のDocker Desktop環境では、コンテナ内のrootが生成したファイルでもホスト側からは通常のユーザー権限としてマッピングされるため、この方法が最も簡単で実用的です。
2. **CI 環境에서의 사전 디렉토리 생성 및 권한 부여 (GitHub Actions)**
   GitHub Actions 워크플로우(`.github/workflows/ci.yml`)에서 테스트 컨테이너를 구동하기 전, 미리 `logs`, `.pytest_cache` 디렉토리를 명시적으로 생성하고 쓰기 권한을 부여하도록 처리합니다。
   ```bash
   mkdir -p backend/logs backend/.pytest_cache
   chmod -R 777 backend/logs backend/.pytest_cache
   ```
