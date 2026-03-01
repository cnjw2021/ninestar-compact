# CI テスト アーキテクチャ

> **最終更新:** 2026-03-01  
> **対象ブランチ:** `fix/integration-test-seeding`

## 概要

本プロジェクトの CI パイプラインは、テストを **単体テスト (Unit Test)** と **統合テスト (Integration / E2E Test)** に分離し、それぞれ異なるトリガーで実行します。

| テスト種別 | トリガー | ワークフロー | Makefile ターゲット | DB 必要 |
|-----------|---------|-------------|-------------------|---------|
| 単体テスト | Push / PR → `main` (自動) | `ci.yml` | `make test-unit` | ❌ |
| 統合テスト | `workflow_dispatch` (手動) | `integration-test.yml` | `make test-integration` | ✅ |
| 全テスト | ローカル実行 | — | `make test` | ✅ |

---

## テスト分類

### 単体テスト (23件) — DB 不要
```
tests/unit/test_daily_star_reading_use_case.py
tests/unit/test_reading_query_use_case.py
tests/unit/test_star_catalog_use_case.py
tests/test_generate_report_happy.py
tests/test_generate_report_partner.py
tests/test_generate_report_use_case_fakes.py
tests/test_generate_report_validation.py
tests/test_solar_starts_repository_param.py
tests/test_solar_terms_boundaries.py
```

### 統合テスト (35件) — バックエンド API + DB 必須
```
tests/golden_master/test_annual_directions.py
tests/golden_master/test_auspicious_days_report.py
tests/golden_master/test_daily_star_reading.py
tests/golden_master/test_direction_fortune.py
tests/golden_master/test_month_acquired_fortune.py
tests/golden_master/test_month_star_readings.py
tests/golden_master/test_star_attributes.py
tests/golden_master/test_star_life_guidance.py
tests/golden_master/test_year_acquired_fortune.py
tests/golden_master/test_year_star.py
tests/test_direction_fortune_birthdate_2026.py
```

---

## 調査・修正の経緯

### Phase 1: 基本的な CI セットアップ

**問題:** GitHub Actions で `make test` を実行するとすべてのテストが失敗。

**調査結果:**
- `PermissionError: [Errno 13] Permission denied: '/app/logs'` — Docker コンテナ内のユーザー権限問題
- `backend-test` コンテナが `appuser` として実行され、ログディレクトリへの書き込み不可

**修正:**
- `docker-compose.dev.yml` の `backend-test` に `user: root` を追加
- CI ワークフローで `mkdir -p backend/logs backend/.pytest_cache && chmod -R 777` を実行

---

### Phase 2: バックエンドコンテナのヘルスチェック失敗

**問題:** `dependency failed to start: container backend-container is unhealthy`

**調査結果:**
1. **Linux ファイル権限の衝突:** `db_manage.py init` が `root` として `/app/logs/app.log` を作成 → その後 `gunicorn` が `appuser` として起動 → Permission Denied で worker が全滅
2. **GitHub Actions の遅い環境:** 2コア runner でのヘルスチェックタイムアウト

**修正:**
- `start.sh` に `chown -R appuser:appgroup /app/logs` を追加（`gunicorn` fork 前）
- ヘルスチェックの `start_period: 30s`, `retries: 15` に増加

---

### Phase 3: データベース接続エラー (Access Denied)

**問題:** `Access denied for user 'ninestarki'@'172.18.0.4' (using password: YES)`

**調査結果（根本原因の特定に至るまでの調査）:**

1. **環境変数の伝搬経路の分析:**
   ```
   ci.yml env → .env (root) → docker-compose.yml → mysql コンテナ
                             → backend/.env.development.backend → backend コンテナ
   ```

2. **`touch` vs `>` の違い:**
   - `touch backend/.env.production.backend` → **ファイル内容は保持される**（タイムスタンプのみ更新）
   - `> backend/.env.production.backend` → **ファイル内容が空になる**

3. **`DATABASE_URL` の優先順位問題:**
   - `backend/.env.production.backend` が **Git にコミット** されていた
   - 内容: `DATABASE_URL=mysql+pymysql://ninestarki:ninestarki_password@mysql:3306/ninestarki`
   - `core/db_config.py` は `DATABASE_URL` を `DB_USER` より**優先**して使用（line 89）
   - CI で `DB_USER=superuser` を設定しても、`DATABASE_URL` が勝つため常に `ninestarki` で接続

**修正:**
```yaml
# ci.yml - 本番環境ファイルをtruncate (touch ではなく >)
> backend/.env.production.backend

# 開発用 .env に DATABASE_URL を含む全変数を生成
echo "DATABASE_URL=mysql+pymysql://${DB_USER}:${DB_PASSWORD}@mysql:3306/${DB_NAME}?charset=utf8mb4" >> backend/.env.development.backend
```

---

### Phase 4: 単体テスト / 統合テスト の分離

**問題:** DB が空の状態では統合テストが必ず失敗する（`No yearly_info for 2025` 等）

**判断:** CI の自動テストは単体テストのみに限定し、統合テストは `workflow_dispatch` で手動実行する

**修正:**
- `ci.yml`: `make test` → `make test-unit` に変更
- `integration-test.yml`: 新規作成（`workflow_dispatch` トリガー）
- `Makefile`: `test-unit`, `test-integration`, `db-seed` ターゲット追加

---

### Phase 5: 統合テスト用のデータシーディング

**問題:** `make test-integration` を実行しても DB が空で全テスト失敗

**調査結果（3つのバグを段階的に発見）:**

| # | エラーメッセージ | 原因 | 修正 |
|---|----------------|------|------|
| 1 | `Access denied for user 'ninestarki'` | `backend-test` に `env_file` がなく、デフォルトの `ninestarki` 資格情報を使用 | `docker-compose.dev.yml` に `env_file: ./backend/.env.development.backend` 追加 |
| 2 | `Table 'ninestarki.zodiac_groups' doesn't exist` | `db_manage.py reset` がテーブル作成後に `commit()` せず、別コネクションの CSV ローダーからテーブルが見えない | `conn.commit()` をテーブル作成直後に追加 |
| 3 | `SQLファイル 'mysql/init/xxx.sql' を見つけることができません` | `backend-test` コンテナ内の CWD は `/app` (= `./backend`)、だが SQL ファイルは `./mysql/init/` (リポジトリルート) にある | ボリュームマウント `./mysql/init:/app/mysql/init` 追加 |

**最終的な `docker-compose.dev.yml` の `backend-test` 修正:**
```yaml
backend-test:
  user: root
  volumes:
    - ./backend:/app
    - ./mysql/init:/app/mysql/init      # SQL seed scripts
    - ./backend/data:/var/lib/mysql-files  # CSV files for LOAD DATA INFILE
  env_file:
    - ./backend/.env.development.backend
  environment:
    - PYTHONPATH=/app
```

---

## データシーディング パイプライン

統合テスト実行時、以下の順序でデータが投入されます：

```mermaid
graph TD
    A[MySQL コンテナ起動] -->|docker-entrypoint-initdb.d| B[000_create_tables.sql<br/>テーブル作成]
    B --> C[001_create_users.sql<br/>権限設定]
    C --> D[100_stars.sql ~ 900_system_data.sql<br/>SQL INSERT データ]
    D --> E[make db-seed]
    E -->|db_manage.py reset| F[テーブル DROP & 再作成]
    F -->|conn.commit| G[SQL ファイルで INSERT]
    G --> H[load_all_csv_data<br/>CSV LOAD DATA INFILE]
    H --> I[create_superuser<br/>スーパーユーザー作成]
    I --> J[統合テスト実行<br/>make test-integration]
```

### CSV でロードされるデータ
| CSV ファイル | テーブル |
|------------|---------|
| `solar_terms_data.csv` | `solar_terms` |
| `solar_starts_data.csv` | `solar_starts` |
| `daily_astrology_data.csv` | `daily_astrology` |
| `star_life_guidance.csv` | `star_life_guidance` |
| `pattern_switch_dates.csv` | `pattern_switch_dates` |
| `zodiac_groups.csv` | `zodiac_groups` |
| `zodiac_group_members.csv` | `zodiac_group_members` |
| `hourly_star_zodiacs.csv` | `hourly_star_zodiacs` |
| `compatibility_master_*.csv` (9件) | `compatibility_master` |
| その他 | `star_compatibility_matrix`, `compatibility_readings_master` 等 |

---

## 使用方法

### ローカルでの実行

```bash
# 全テスト実行
make test

# 単体テストのみ
make test-unit

# 統合テストのみ (事前に make up ENV=dev でDBを起動)
make test-integration

# DB データを完全にリセット＆再投入
make db-seed
```

### GitHub Actions での実行

| 操作 | 方法 |
|------|------|
| 単体テスト | `main` への Push / PR で自動実行 |
| 統合テスト | GitHub → Actions → "Integration Tests (Manual)" → "Run workflow" → ブランチ選択 → Run |
| 特定テスト | `test_path` に `tests/golden_master/test_year_star.py` 等を入力 |

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `.github/workflows/ci.yml` | 自動 CI (単体テストのみ) |
| `.github/workflows/integration-test.yml` | 手動統合テスト |
| `Makefile` | `test`, `test-unit`, `test-integration`, `db-seed` ターゲット |
| `docker-compose.dev.yml` | `backend-test` サービス定義 |
| `backend/db_manage.py` | `init` (スーパーユーザーのみ) / `reset` (全データ再投入) |
| `backend/scripts/csv_file_loader.py` | CSV データローダー |
| `mysql/init/*.sql` | MySQL 初期化スクリプト |
| `backend/core/db_config.py` | DB 接続情報管理 (`DATABASE_URL` 優先) |
