import Testing
@testable import GrepCore

@Test func 로그인방식이_정의되어있을때_전체를_나열하면_Google과_GitHub_둘뿐인지() {
    // given
    let expected = ["google", "github"]

    // when
    let providers = AuthProvider.allCases.map(\.rawValue)

    // then
    #expect(providers == expected)
}
