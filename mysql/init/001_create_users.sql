-- テーブル作成後の権限設定
-- このスクリプトはDockerコンテナ初期化時にrootユーザーとして実行されます

-- データベース操作権限
GRANT ALL PRIVILEGES ON ninestarki.* TO 'ninestarki'@'%';

-- CSVロード用のFILE権限
GRANT FILE ON *.* TO 'ninestarki'@'%';

-- 権限変更を反映
FLUSH PRIVILEGES; 