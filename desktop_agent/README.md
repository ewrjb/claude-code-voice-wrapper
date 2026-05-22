# Desktop Agent

Claude Code Voice Wrapper의 데스크탑 에이전트.  
릴레이 서버로부터 음성 명령을 수신해 Claude Code CLI를 실행하고 응답을 반송한다.

## 요구 사항

- Python 3.11+
- Claude Code CLI 설치 및 로그인 완료 (`claude --version`으로 확인)

## 설치

```bash
cd desktop_agent
pip install -r requirements.txt
```

## 실행 (수동)

```bash
# .env 파일 설정
cp .env.example .env
# .env 편집: RELAY_URL, TOKEN, WORKING_DIR 입력

cd desktop_agent
python agent.py
```

## JWT 토큰 발급

릴레이 서버에 계정이 없으면 먼저 가입:

```bash
curl -X POST http://YOUR_RELAY_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"yourpassword"}'
```

로그인하여 토큰 발급:

```bash
curl -X POST http://YOUR_RELAY_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"yourpassword"}'
# 응답: {"access_token": "eyJ..."}
```

## 보안 주의사항

- JWT 토큰은 WebSocket URL 쿼리 파라미터로 전송됩니다 (`?token=...`). 서버 접근 로그에 남을 수 있으니 공유 서버에서 로그 관리에 주의하세요.
- `--permission-mode auto` 옵션으로 인해 에이전트는 파일 수정·명령 실행 권한을 자동 승인합니다. 신뢰할 수 없는 네트워크에서는 사용하지 마세요.
- plist 파일에 토큰이 평문 저장됩니다. `chmod 600` 적용을 잊지 마세요 (설치 단계에 포함).

## macOS 부팅 시 자동 실행 (launchd)

> **주의:** 운영 서버에 배포 시 RELAY_URL을 반드시 `wss://`(암호화)로 변경하세요. `ws://`는 개발/로컬 환경에서만 사용하세요.

1. `com.voicedev.agent.plist` 파일을 열어 세 곳을 수정:
   - `ProgramArguments[1]`: `agent.py`의 절대 경로
   - `TOKEN`: 위에서 발급한 JWT 토큰
   - `WORKING_DIR`: Claude가 작업할 프로젝트 디렉터리

2. plist를 LaunchAgents에 복사:

```bash
cp com.voicedev.agent.plist ~/Library/LaunchAgents/
```

3. **보안**: plist에 JWT 토큰이 포함되어 있으므로 파일 권한을 제한하세요:

```bash
chmod 600 ~/Library/LaunchAgents/com.voicedev.agent.plist
```

4. 등록 및 시작:

```bash
launchctl load ~/Library/LaunchAgents/com.voicedev.agent.plist
```

확인:

```bash
launchctl list com.voicedev.agent   # Status: 0이면 정상 실행 중
tail -f /tmp/voicedev-agent.log     # 로그 확인
```

5. 중지:

```bash
launchctl unload ~/Library/LaunchAgents/com.voicedev.agent.plist
```

제거:

```bash
launchctl unload ~/Library/LaunchAgents/com.voicedev.agent.plist
rm ~/Library/LaunchAgents/com.voicedev.agent.plist
```
