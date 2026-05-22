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

## macOS 부팅 시 자동 실행 (launchd)

1. `com.voicedev.agent.plist` 파일을 열어 세 곳을 수정:
   - `ProgramArguments[1]`: `agent.py`의 절대 경로
   - `TOKEN`: 위에서 발급한 JWT 토큰
   - `WORKING_DIR`: Claude가 작업할 프로젝트 디렉터리

2. plist를 LaunchAgents에 복사:

```bash
cp com.voicedev.agent.plist ~/Library/LaunchAgents/
```

3. 등록 및 시작:

```bash
launchctl load ~/Library/LaunchAgents/com.voicedev.agent.plist
```

4. 로그 확인:

```bash
tail -f /tmp/voicedev-agent.log
```

5. 중지:

```bash
launchctl unload ~/Library/LaunchAgents/com.voicedev.agent.plist
```
