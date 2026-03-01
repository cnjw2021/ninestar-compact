#!/bin/bash
set -e

# ==============================================================================
# 수동 배포 스크립트 (ConoHa 서버용)
# ==============================================================================
# GitHub Actions CI가 빌드한 GHCR 이미지를 Pull하여 배포합니다.
#
# 사전 요구사항:
#   1. GHCR 로그인: docker login ghcr.io -u <GITHUB_USER> -p <GITHUB_TOKEN>
#   2. 서버에 아래 파일들이 존재해야 합니다:
#      - docker-compose.prod.yml
#      - .env.production.backend
#      - .env.production.frontend
#      - nginx/conf.d/  (nginx 설정)
#      - certbot/       (SSL 인증서)
#      - mysql/init/    (DB 초기화 스크립트, 최초 배포 시)
# ==============================================================================

COMPOSE_FILE="docker-compose.prod.yml"
REGISTRY="ghcr.io/cnjw2021/ninestar-compact"

# --------------------------------------------------
# 환경변수 로드 (docker-compose 파일의 ${...} 치환을 위함)
# --------------------------------------------------
if [ -f ".env.production.backend" ]; then
    set -a
    source .env.production.backend
    set +a
else
    echo -e "\033[0;31m❌ .env.production.backend 파일을 찾을 수 없습니다.\033[0m"
    exit 1
fi

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== 배포 시작 =====${NC}"
echo ""

# --------------------------------------------------
# 1. 최신 이미지 가져오기
# --------------------------------------------------
echo -e "${YELLOW}1. 최신 이미지 가져오기${NC}"
docker pull ${REGISTRY}-frontend:latest
docker pull ${REGISTRY}-backend:latest
docker pull ${REGISTRY}-nginx:latest
echo ""

# --------------------------------------------------
# 2. 기존 컨테이너 중지 및 새 컨테이너 실행
# --------------------------------------------------
echo -e "${YELLOW}2. 컨테이너 재시작${NC}"
docker compose -f ${COMPOSE_FILE} down
docker compose -f ${COMPOSE_FILE} up -d
echo ""

# --------------------------------------------------
# 3. 헬스체크 대기
# --------------------------------------------------
echo -e "${YELLOW}3. 백엔드 헬스체크 대기 (최대 60초)${NC}"
RETRY=0
MAX_RETRY=12
until docker exec backend-container curl -sf http://localhost:5001/auth/health > /dev/null 2>&1; do
    RETRY=$((RETRY + 1))
    if [ $RETRY -ge $MAX_RETRY ]; then
        echo -e "${RED}❌ 백엔드 헬스체크 실패! 로그를 확인하세요:${NC}"
        echo "   docker compose -f ${COMPOSE_FILE} logs backend"
        exit 1
    fi
    echo "   대기 중... (${RETRY}/${MAX_RETRY})"
    sleep 5
done
echo -e "${GREEN}   ✅ 백엔드 정상 기동 확인${NC}"
echo ""

# --------------------------------------------------
# 4. 사용하지 않는 구버전 이미지 정리
# --------------------------------------------------
echo -e "${YELLOW}4. 구버전 이미지 정리${NC}"
docker image prune -f
echo ""

# --------------------------------------------------
# 완료
# --------------------------------------------------
echo -e "${GREEN}===== 배포 완료! =====${NC}"
echo ""
docker compose -f ${COMPOSE_FILE} ps
