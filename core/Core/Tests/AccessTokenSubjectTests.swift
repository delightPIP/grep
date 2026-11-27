import Testing
@testable import GrepCore

@Test func JWT접근토큰이있을때_주체를읽으면_sub를돌려주는지() {
    // given: {"alg":"ES256"}.{"sub":"user-a","exp":1}.signature
    let token = "eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ1c2VyLWEiLCJleHAiOjF9.c2ln"

    // when
    let subject = AccessTokenSubject.read(from: token)

    // then
    #expect(subject == "user-a")
}

@Test func 패딩없는base64url본문일때_주체를읽으면_sub를돌려주는지() {
    // given: {"sub":"~~~"} → base64url "eyJzdWIiOiJ-fn4ifQ"('-' 포함, 패딩 '==' 뺌)
    let token = "h.eyJzdWIiOiJ-fn4ifQ.s"

    // when
    let subject = AccessTokenSubject.read(from: token)

    // then
    #expect(subject == "~~~")
}

@Test(arguments: ["token", "a.b", "a.!!!.c", "a.eyJleHAiOjF9.c"])
func JWT형식이아니거나sub가없을때_주체를읽으면_nil인지(token: String) {
    // given: token

    // when
    let subject = AccessTokenSubject.read(from: token)

    // then
    #expect(subject == nil)
}
