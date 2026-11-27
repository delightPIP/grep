import Testing
@testable import GrepCore

@Test func 로그인방식이정의되어있을때_전체를나열하면_Google과GitHub둘뿐인지() {
    // given
    let expected = ["google", "github"]

    // when
    let providers = AuthProvider.allCases.map(\.rawValue)

    // then
    #expect(providers == expected)
}
