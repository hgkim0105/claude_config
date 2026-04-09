# Project Rules

## Architecture: Clean Architecture

의존성 방향: `Presentation → Application → Domain ← Infrastructure`

### 레이어 규칙
- **domain**: 외부 의존 없음. 프레임워크 import 금지. 순수 비즈니스 모델
- **application/use_cases**: domain만 의존. 1 use case = 1 클래스 (`execute()` 메서드)
- **infrastructure**: domain 인터페이스(ABC) 구체 구현. DB/외부 API는 여기서만
- **presentation**: use_case 호출 후 응답 변환. 비즈니스 로직 작성 금지

### 핵심 패턴
- Repository: domain에 ABC 정의 → infrastructure에 구체 구현
- Error handling: domain 예외 → presentation에서 HTTP 응답 변환 (라우터 try/except 금지)
- DI: 생성자 주입으로 use case에 repository 전달

---

## TDD Loop 규칙

- 구현 전 반드시 테스트 먼저 작성 (실패 확인 후 구현 시작)
- 구현 후 테스트 실행
- 실패 시: 에러 분석 → 수정 → 재실행 (최대 5회)
- 5회 초과 실패 시: 사용자에게 상황 보고 후 대기
- 전체 통과 시: 완료 보고

---

## Code Style
- 타입 힌트 필수
- 주석: 로직이 자명하지 않을 때만
- 함수/변수명: 의미 있는 이름, 축약 금지
- 테스트 파일명: `test_{resource}`
- 테스트 함수명: `test_{method}_{scenario}`
