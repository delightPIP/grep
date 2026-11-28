#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FeatureTerminalInterface
import GrepCore
import RIBs

typealias TerminalRouter = ViewableRouter<TerminalInteractor, any TerminalViewControllable>
