#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# AWS 인프라 초기 셋업 스크립트 (도메인 없는 버전)
# 실행: bash scripts/setup-aws.sh
# 사전 준비: AWS CLI 설치 + aws configure 완료
# ─────────────────────────────────────────────────────────────────────────────
set -e

# ── 설정값 ───────────────────────────────────────────────────────────────────
BUCKET_NAME="momo-flower-puzzle-game"
REGION="ap-northeast-2"
# ─────────────────────────────────────────────────────────────────────────────

echo "AWS 인프라 셋업 시작..."

# 1. S3 버킷 생성
echo "S3 버킷 생성 중..."
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || echo "버킷 이미 존재, 건너뜀"

aws s3 website "s3://$BUCKET_NAME" \
  --index-document index.html \
  --error-document index.html

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "S3 버킷 생성 완료: $BUCKET_NAME"

# 2. CloudFront OAC 생성
echo "CloudFront 배포 생성 중..."

OAC_ID=$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='MomoFlowerOAC'].Id | [0]" \
  --output text)

if [ -z "$OAC_ID" ] || [ "$OAC_ID" = "None" ]; then
  OAC_ID=$(aws cloudfront create-origin-access-control \
    --origin-access-control-config \
      "Name=MomoFlowerOAC,Description=OAC for Momo Flower Puzzle,SigningProtocol=sigv4,SigningBehavior=always,OriginAccessControlOriginType=s3" \
    --query "OriginAccessControl.Id" \
    --output text)
  echo "OAC 생성: $OAC_ID"
else
  echo "기존 OAC 재사용: $OAC_ID"
fi

# 3. CloudFront 배포 생성 (도메인/SSL 없이 기본 CloudFront URL 사용)
CF_CONFIG="$HOME/cf-config.json"
python3 -c "
import json, sys, time
cfg = {
  'CallerReference': 'momo-flower-' + str(int(time.time())),
  'Comment': 'Momo Flower Puzzle CDN',
  'DefaultRootObject': '260403_momo_flower_puzzle.html',
  'Origins': {
    'Quantity': 1,
    'Items': [{
      'Id': 'S3-$BUCKET_NAME',
      'DomainName': '$BUCKET_NAME.s3.$REGION.amazonaws.com',
      'OriginAccessControlId': '$OAC_ID',
      'S3OriginConfig': {'OriginAccessIdentity': ''}
    }]
  },
  'DefaultCacheBehavior': {
    'TargetOriginId': 'S3-$BUCKET_NAME',
    'ViewerProtocolPolicy': 'redirect-to-https',
    'CachePolicyId': '658327ea-f89d-4fab-a63d-7e88639e58f6',
    'Compress': True,
    'AllowedMethods': {
      'Quantity': 2,
      'Items': ['GET', 'HEAD'],
      'CachedMethods': {'Quantity': 2, 'Items': ['GET', 'HEAD']}
    }
  },
  'Enabled': True,
  'HttpVersion': 'http2and3',
  'PriceClass': 'PriceClass_200'
}
print(json.dumps(cfg))
" > "$CF_CONFIG"

CF_RESULT=$(aws cloudfront create-distribution --distribution-config "file://$CF_CONFIG")
CF_ID=$(echo "$CF_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['Distribution']['Id'])")
CF_DOMAIN=$(echo "$CF_RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['Distribution']['DomainName'])")

echo "CloudFront 배포 ID: $CF_ID"
echo "CloudFront 도메인: https://$CF_DOMAIN"

# 4. S3 버킷 정책 (CloudFront OAC만 허용)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

BUCKET_POLICY="$HOME/bucket-policy.json"
cat > "$BUCKET_POLICY" << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFrontOAC",
    "Effect": "Allow",
    "Principal": { "Service": "cloudfront.amazonaws.com" },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::$BUCKET_NAME/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "arn:aws:cloudfront::$ACCOUNT_ID:distribution/$CF_ID"
      }
    }
  }]
}
EOF

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "file://$BUCKET_POLICY"
echo "S3 버킷 정책 적용 완료"

# 5. GitHub Secrets 안내
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GitHub Secrets에 아래 값을 추가하세요:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "S3_BUCKET_NAME                 = $BUCKET_NAME"
echo "CLOUDFRONT_DISTRIBUTION_ID     = $CF_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "게임 URL (배포 완료 후 약 15분 뒤 접속 가능):"
echo "https://$CF_DOMAIN"
echo ""
echo "셋업 완료! 이제 git push만 하면 자동 배포됩니다."
