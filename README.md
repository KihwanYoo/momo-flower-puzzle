# 🎮 Momo Flower Puzzle — 배포 가이드

HTML 게임을 **웹(AWS)** 과 **앱스토어(iOS/Android)** 에 자동으로 배포하는 파이프라인입니다.

---

## 📁 파일 구조

```
.
├── 260403_momo_flower_puzzle.html    ← 게임 파일
├── capacitor.config.json             ← 앱 래핑 설정
├── package.json
├── scripts/
│   └── setup-aws.sh                  ← AWS 인프라 최초 셋업 (1회만 실행)
└── .github/
    └── workflows/
        ├── deploy-aws.yml            ← git push → 웹 자동 배포
        └── build-app.yml             ← git tag → 앱 빌드 + 스토어 업로드
```

---

## 🚀 시작하기

### 1단계: AWS 인프라 셋업 (최초 1회)

```bash
# AWS CLI 설치 및 로그인
brew install awscli          # macOS
aws configure                # Access Key, Secret Key, 리전 입력

# setup-aws.sh 안에서 BUCKET_NAME, DOMAIN_NAME 수정 후 실행
bash scripts/setup-aws.sh
```

### 2단계: GitHub Secrets 등록

GitHub 저장소 → Settings → Secrets → Actions에 아래 항목 추가:

| Secret 이름 | 값 |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM 사용자 Access Key |
| `AWS_SECRET_ACCESS_KEY` | IAM 사용자 Secret Key |
| `S3_BUCKET_NAME` | setup-aws.sh에서 출력된 버킷 이름 |
| `CLOUDFRONT_DISTRIBUTION_ID` | setup-aws.sh에서 출력된 CF ID |
| `DOMAIN_NAME` | 내 도메인 (예: game.mydomain.com) |
| `ADSENSE_CLIENT_ID` | ca-pub-XXXXXXXXXXXXXXXX |
| `ANDROID_SIGNING_KEY` | keystore를 base64 인코딩한 값 |
| `ANDROID_KEY_ALIAS` | 키 alias |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 비밀번호 |
| `ANDROID_KEY_PASSWORD` | 키 비밀번호 |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Google Play API JSON (서비스 계정) |
| `IOS_CERTIFICATE_P12` | iOS 배포 인증서 (.p12) base64 |
| `IOS_CERTIFICATE_PASSWORD` | .p12 비밀번호 |
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |
| `APPSTORE_API_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_API_PRIVATE_KEY` | App Store Connect API Private Key |

### 3단계: 앱 ID 변경

`capacitor.config.json`에서 `com.yourname.momoflower` 부분을 본인의 앱 ID로 변경하세요.  
예: `com.kimcoding.momoflower`

### 4단계: 첫 앱 프로젝트 생성 (로컬에서 1회)

```bash
npm install
npx cap add android
npx cap add ios       # macOS만 가능
npx cap sync
```

이후 `android/` 와 `ios/` 폴더가 생성됩니다. 이 폴더도 git에 커밋하세요.

---

## ✅ 배포 방법

### 웹 게임 배포

```bash
git add .
git commit -m "update game"
git push origin main        # → 자동으로 S3 + CloudFront 배포
```

### 앱스토어 빌드 + 업로드

```bash
git tag v1.0.0
git push origin v1.0.0      # → 자동으로 iOS/Android 빌드 + 스토어 업로드
```

---

## 💰 광고 수익화

### 웹 (Google AdSense)
1. [AdSense 가입](https://adsense.google.com) 후 게임 사이트 등록
2. GitHub Secrets에 `ADSENSE_CLIENT_ID` 추가
3. `deploy-aws.yml`이 자동으로 HTML에 AdSense 코드 삽입

### 앱 (Google AdMob)
1. [AdMob 가입](https://admob.google.com) 후 앱 등록
2. `capacitor.config.json`의 `appId` 값을 AdMob 앱 ID로 변경
3. HTML 파일에 AdMob 광고 코드 추가:

```javascript
// game HTML 파일 내에 추가
if (window.Capacitor) {
  // 앱 환경: AdMob 배너 광고
  import('@capacitor-community/admob').then(({ AdMob }) => {
    AdMob.initialize();
    AdMob.showBanner({
      adId: 'ca-app-pub-XXXXXXXX/XXXXXXXX',
      adSize: 'BANNER',
      position: 'BOTTOM_CENTER',
    });
  });
}
```

---

## 📱 앱스토어 등록 전 체크리스트

### App Store (iOS)
- [ ] Apple Developer Program 가입 ($99/년)
- [ ] App Store Connect에서 앱 등록
- [ ] 앱 아이콘 1024×1024px 준비
- [ ] 스크린샷 6.7인치, 6.5인치, 5.5인치 준비
- [ ] 개인정보 처리방침 URL 준비

### Google Play (Android)
- [ ] Google Play Console 가입 ($25 일회성)
- [ ] 앱 서명 키스토어 생성: `keytool -genkey -v -keystore momo.keystore -alias momo -keyalg RSA -keysize 2048 -validity 10000`
- [ ] 앱 아이콘 512×512px 준비
- [ ] 스크린샷 최소 2장 준비
- [ ] 개인정보 처리방침 URL 준비

---

## 🔑 Android Keystore를 GitHub Secret으로 변환

```bash
base64 -i momo.keystore | pbcopy   # macOS: 클립보드에 복사
# 복사된 값을 ANDROID_SIGNING_KEY Secret에 붙여넣기
```
