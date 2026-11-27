// Swift(Wasm) 쪽 진입점과 BridgeJS가 만든 타입. `swift package --swift-sdk <wasm SDK> js`가 먼저 돌아야 있다.
export { init } from "../.build/plugins/PackageToJS/outputs/Package/index.js";
export type * from "../.build/plugins/PackageToJS/outputs/Package/bridge-js";
