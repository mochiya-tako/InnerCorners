import CoreGraphics
import XCTest
@testable import InnerCorners

final class CursorBarrierGeometryTests: XCTestCase {
    private let lg = QuartzDisplayDescriptor(id: 1, name: "LG", frame: CGRect(x: 0, y: 0, width: 2560, height: 1080))
    private let asm = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: -119, width: 1920, height: 1080))

    func testCurrentLayoutCreatesTwoDirectionalInnerCornerWalls() throws {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let lgWall = try XCTUnwrap(barriers.first { $0.displayID == 1 && $0.corner == .topLeft && $0.axis == .vertical })
        let asmWall = try XCTUnwrap(barriers.first { $0.displayID == 3 && $0.corner == .bottomRight && $0.axis == .vertical })

        XCTAssertEqual(lgWall.coordinate, 0)
        XCTAssertEqual(lgWall.span, -40...40)
        XCTAssertEqual(lgWall.ownerSide, .higherCoordinate)
        XCTAssertEqual(asmWall.span, 921...1001)
        XCTAssertEqual(asmWall.ownerSide, .lowerCoordinate)
    }

    func testLGWallBlocksOnlyMovementFromLGToASM() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        XCTAssertEqual(CursorBarrierGeometry.constrain(from: CGPoint(x: 10, y: 20), to: CGPoint(x: -10, y: 20), barriers: barriers), CGPoint(x: 0.5, y: 20))
        XCTAssertEqual(CursorBarrierGeometry.constrain(from: CGPoint(x: -10, y: 20), to: CGPoint(x: 10, y: 20), barriers: barriers), CGPoint(x: 10, y: 20))
    }

    func testASMWallBlocksOnlyMovementFromASMToLG() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        XCTAssertEqual(CursorBarrierGeometry.constrain(from: CGPoint(x: -10, y: 950), to: CGPoint(x: 10, y: 950), barriers: barriers), CGPoint(x: -0.5, y: 950))
        XCTAssertEqual(CursorBarrierGeometry.constrain(from: CGPoint(x: 10, y: 950), to: CGPoint(x: -10, y: 950), barriers: barriers), CGPoint(x: -10, y: 950))
    }

    func testFastDiagonalMotionUsesBoundaryIntersection() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let result = CursorBarrierGeometry.constrain(from: CGPoint(x: 100, y: 10), to: CGPoint(x: -100, y: 50), barriers: barriers)
        XCTAssertEqual(result.x, 0.5)
        XCTAssertEqual(result.y, 30)
    }

    func testFastMotionEndingAtCornerCannotSkipWall() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let result = CursorBarrierGeometry.constrain(from: CGPoint(x: 200, y: 200), to: CGPoint(x: -200, y: 10), barriers: barriers)
        XCTAssertEqual(result, CGPoint(x: 0.5, y: 10))
    }

    func testRepeatedExactOuterCornerCollisionStaysInsideOwnerDisplay() throws {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 88)
        let owned = barriers.filter { $0.displayID == 1 }
        let first = try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: 180, y: 180),
            to: CGPoint(x: -200, y: 0),
            barriers: owned
        ))
        let repeated = try XCTUnwrap(CursorBarrierGeometry.collision(
            from: first.point,
            to: CGPoint(x: -200, y: 0),
            barriers: owned
        ))

        XCTAssertEqual(first.point, CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(repeated.point, CGPoint(x: 0.5, y: 0.5))
    }

    func testExactTopLeftArrivalCountsAsContactWithoutSeamCrossing() throws {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 88)
        let contact = try XCTUnwrap(CursorBarrierGeometry.cornerContact(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 0, y: 0),
            barriers: barriers.filter { $0.displayID == 1 }
        ))

        XCTAssertEqual(contact.barrier.corner, .topLeft)
        XCTAssertEqual(contact.point, CGPoint(x: 0.5, y: 0.5))
    }

    func testExactBottomRightArrivalCountsAsContactWithoutSeamCrossing() throws {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 88)
        let contact = try XCTUnwrap(CursorBarrierGeometry.cornerContact(
            from: CGPoint(x: -100, y: 900),
            to: CGPoint(x: 0, y: 961),
            barriers: barriers.filter { $0.displayID == 3 }
        ))

        XCTAssertEqual(contact.barrier.corner, .bottomRight)
        XCTAssertEqual(contact.point, CGPoint(x: -0.5, y: 960.5))
    }

    func testRemainingAtExactCornerDoesNotCreateRepeatedContact() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 88)
        XCTAssertNil(CursorBarrierGeometry.cornerContact(
            from: CGPoint(x: -0.5, y: 1079.5),
            to: CGPoint(x: 0, y: 1080),
            barriers: barriers.filter { $0.displayID == 3 }
        ))
    }

    func testMovementAwayFromBoundaryWithinToleranceDoesNotCreateCornerContact() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 88)
        let lgVerticalWall = barriers.filter {
            $0.displayID == 1 && $0.corner == .topLeft && $0.axis == .vertical
        }

        XCTAssertNil(CursorBarrierGeometry.cornerContact(
            from: CGPoint(x: 0.5, y: 1.2),
            to: CGPoint(x: 0.8, y: 0.8),
            barriers: lgVerticalWall
        ))
    }

    func testSparseFastSamplesJustBeyondSpanCannotTunnelIntoCorner() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 88)
        let result = CursorBarrierGeometry.collision(
            from: CGPoint(x: 53, y: 120),
            to: CGPoint(x: -10, y: 90),
            barriers: barriers.filter { $0.displayID == 1 }
        )

        XCTAssertEqual(result?.point, CGPoint(x: 0.5, y: 88))
        XCTAssertEqual(result?.barrier.corner, .topLeft)
    }

    func testSamplingAllowanceStaysCappedAwayFromCorner() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let result = CursorBarrierGeometry.collision(
            from: CGPoint(x: 200, y: 100),
            to: CGPoint(x: -200, y: 100),
            barriers: barriers.filter { $0.displayID == 1 }
        )

        XCTAssertNil(result)
    }

    func testDiagonalMotionBeyondTopPinsToActualTopLeftCorner() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let result = CursorBarrierGeometry.constrain(
            from: CGPoint(x: 20, y: 5),
            to: CGPoint(x: -20, y: -20),
            barriers: barriers
        )
        XCTAssertEqual(result, CGPoint(x: 0.5, y: 0.5))
    }

    func testDiagonalMotionBeyondBottomPinsToActualBottomRightPixel() {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let result = CursorBarrierGeometry.constrain(
            from: CGPoint(x: -20, y: 955),
            to: CGPoint(x: 20, y: 980),
            barriers: barriers
        )
        XCTAssertEqual(result, CGPoint(x: -0.5, y: 960.5))
    }

    func testLatchRearmsAfterLeavingCornerRegardlessOfWallLength() throws {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 40)
        let wall = try XCTUnwrap(barriers.first { $0.displayID == 1 && $0.corner == .topLeft })
        XCTAssertFalse(CursorBarrierGeometry.shouldReleaseLatch(at: CGPoint(x: -8, y: 0), barrier: wall))
        XCTAssertTrue(CursorBarrierGeometry.shouldReleaseLatch(at: CGPoint(x: -9, y: 0), barrier: wall))
        XCTAssertTrue(CursorBarrierGeometry.shouldReleaseLatch(at: CGPoint(x: 0, y: 9), barrier: wall))
    }

    func testLongWallDoesNotIncreaseActionLatchDistance() throws {
        let barriers = CursorBarrierGeometry.barriers(for: [lg, asm], length: 100)
        let wall = try XCTUnwrap(barriers.first { $0.displayID == 1 && $0.corner == .topLeft })

        XCTAssertTrue(CursorBarrierGeometry.shouldReleaseLatch(
            at: CGPoint(x: 12, y: 0), barrier: wall
        ))
    }

    func testSharedDisplayCornersBelongToSamePhysicalJunction() throws {
        let alignedASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let barriers = CursorBarrierGeometry.barriers(for: [lg, alignedASM], length: 40)
        let lgTopLeft = try XCTUnwrap(barriers.first { $0.displayID == 1 && $0.corner == .topLeft })
        let asmTopRight = try XCTUnwrap(barriers.first { $0.displayID == 3 && $0.corner == .topRight })

        XCTAssertTrue(CursorBarrierGeometry.sameJunction(lgTopLeft, asmTopRight))
    }

    func testGenericThreeDisplayLayoutCreatesEveryDirectionalInnerCornerWall() {
        let alignedASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let miTV = QuartzDisplayDescriptor(id: 2, name: "Mi TV", frame: CGRect(x: -1261, y: 1080, width: 2560, height: 1440))
        let barriers = CursorBarrierGeometry.barriers(for: [lg, alignedASM, miTV], length: 40)

        XCTAssertEqual(barriers.count, 8)
        XCTAssertTrue(barriers.contains { $0.displayID == 1 && $0.corner == .topLeft && $0.axis == .vertical })
        XCTAssertTrue(barriers.contains { $0.displayID == 1 && $0.corner == .bottomLeft && $0.axis == .vertical })
        XCTAssertTrue(barriers.contains { $0.displayID == 1 && $0.corner == .bottomLeft && $0.axis == .horizontal })
        XCTAssertTrue(barriers.contains { $0.displayID == 3 && $0.corner == .topRight && $0.axis == .vertical })
        XCTAssertTrue(barriers.contains { $0.displayID == 3 && $0.corner == .bottomRight && $0.axis == .vertical })
        XCTAssertTrue(barriers.contains { $0.displayID == 3 && $0.corner == .bottomRight && $0.axis == .horizontal })
        XCTAssertTrue(barriers.contains { $0.displayID == 2 && $0.corner == .topLeft && $0.axis == .horizontal })
        XCTAssertTrue(barriers.contains { $0.displayID == 2 && $0.corner == .topRight && $0.axis == .horizontal })
    }

    func testCurrentThreeDisplayQuartzLayoutCreatesFourPhysicalInnerCorners() {
        let quartzLG = QuartzDisplayDescriptor(id: 1, name: "LG", frame: CGRect(x: 0, y: 0, width: 2560, height: 1080))
        let quartzMiTV = QuartzDisplayDescriptor(id: 2, name: "Mi TV", frame: CGRect(x: -1261, y: -1080, width: 1920, height: 1080))
        let quartzASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 360, width: 1920, height: 1080))
        let barriers = CursorBarrierGeometry.barriers(for: [quartzLG, quartzMiTV, quartzASM], length: 40)

        XCTAssertEqual(barriers.count, 4)
        XCTAssertTrue(barriers.contains { $0.displayID == 1 && $0.corner == .topLeft && $0.axis == .horizontal })
        XCTAssertTrue(barriers.contains { $0.displayID == 1 && $0.corner == .bottomLeft && $0.axis == .vertical })
        XCTAssertTrue(barriers.contains { $0.displayID == 2 && $0.corner == .bottomRight && $0.axis == .horizontal })
        XCTAssertTrue(barriers.contains { $0.displayID == 3 && $0.corner == .topRight && $0.axis == .vertical })
    }

    func testStableApproachDisplayDoesNotFlipOnSharedEdgeJitter() {
        let alignedASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let displays = [lg, alignedASM]
        let barriers = CursorBarrierGeometry.barriers(for: displays, length: 40)

        XCTAssertEqual(CursorBarrierGeometry.stableDisplayID(
            at: CGPoint(x: 20, y: 1070), displays: displays, barriers: barriers
        ), 1)
        XCTAssertNil(CursorBarrierGeometry.stableDisplayID(
            at: CGPoint(x: 1, y: 1070), displays: displays, barriers: barriers
        ))
        XCTAssertNil(CursorBarrierGeometry.stableDisplayID(
            at: CGPoint(x: -1, y: 1070), displays: displays, barriers: barriers
        ))
        XCTAssertEqual(CursorBarrierGeometry.stableDisplayID(
            at: CGPoint(x: -20, y: 1070), displays: displays, barriers: barriers
        ), 3)
    }

    func testSafeRearmRejectsJunctionAndAcceptsDisplayInterior() {
        let alignedASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let displays = [lg, alignedASM]
        let barriers = CursorBarrierGeometry.barriers(for: displays, length: 100)

        XCTAssertFalse(CursorBarrierGeometry.isSafeRearmPosition(
            CGPoint(x: 0, y: 0), displays: displays, barriers: barriers
        ))
        XCTAssertFalse(CursorBarrierGeometry.isSafeRearmPosition(
            CGPoint(x: 8, y: 50), displays: displays, barriers: barriers
        ))
        XCTAssertTrue(CursorBarrierGeometry.isSafeRearmPosition(
            CGPoint(x: 200, y: 200), displays: displays, barriers: barriers
        ))
        XCTAssertTrue(CursorBarrierGeometry.isSafeRearmPosition(
            CGPoint(x: -200, y: 200), displays: displays, barriers: barriers
        ))
    }

    func testDisplayConfigurationIgnoresOrderAndSubpixelNoise() {
        let a = [lg, asm]
        let noisyLG = QuartzDisplayDescriptor(
            id: lg.id,
            name: "Renamed LG",
            frame: CGRect(x: 0.25, y: -0.25, width: 2560, height: 1080)
        )
        XCTAssertTrue(CursorBarrierGeometry.sameDisplayConfiguration(a, [asm, noisyLG]))
    }

    func testDisplayConfigurationDetectsIDFrameAndCountChanges() {
        XCTAssertFalse(CursorBarrierGeometry.sameDisplayConfiguration(
            [lg, asm],
            [lg, QuartzDisplayDescriptor(id: 3, name: "ASM", frame: asm.frame.offsetBy(dx: 1, dy: 0))]
        ))
        XCTAssertFalse(CursorBarrierGeometry.sameDisplayConfiguration([lg, asm], [lg]))
        XCTAssertFalse(CursorBarrierGeometry.sameDisplayConfiguration(
            [lg],
            [QuartzDisplayDescriptor(id: 99, name: "LG", frame: lg.frame)]
        ))
    }

    func testLLayoutTripleJunctionSelectsOnlyApproachDisplayCorner() throws {
        let lLG = QuartzDisplayDescriptor(id: 1, name: "LG", frame: CGRect(x: 0, y: 0, width: 2560, height: 1080))
        let lMiTV = QuartzDisplayDescriptor(id: 2, name: "Mi TV", frame: CGRect(x: 0, y: -1440, width: 2560, height: 1440))
        let lASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let displays = [lLG, lMiTV, lASM]
        let barriers = CursorBarrierGeometry.barriers(for: displays, length: 40)

        XCTAssertEqual(barriers.count, 8)
        XCTAssertEqual(CursorBarrierGeometry.stableDisplayID(at: CGPoint(x: 20, y: 20), displays: displays, barriers: barriers), 1)
        XCTAssertEqual(CursorBarrierGeometry.stableDisplayID(at: CGPoint(x: 20, y: -20), displays: displays, barriers: barriers), 2)
        XCTAssertEqual(CursorBarrierGeometry.stableDisplayID(at: CGPoint(x: -20, y: 20), displays: displays, barriers: barriers), 3)

        let lgHit = try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: 20, y: 20), to: CGPoint(x: -20, y: -20),
            barriers: barriers.filter { $0.displayID == 1 }
        ))
        XCTAssertEqual(lgHit.barrier.corner, .topLeft)

        let miHit = try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: 20, y: -20), to: CGPoint(x: -20, y: 20),
            barriers: barriers.filter { $0.displayID == 2 }
        ))
        XCTAssertEqual(miHit.barrier.corner, .bottomLeft)

        let asmHit = try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: -20, y: 20), to: CGPoint(x: 20, y: -20),
            barriers: barriers.filter { $0.displayID == 3 }
        ))
        XCTAssertEqual(asmHit.barrier.corner, .topRight)

    }

    func testConvexThreeDisplayLayoutSeparatesCornersFromEdgeIntersections() throws {
        let convexLG = QuartzDisplayDescriptor(id: 1, name: "LG", frame: CGRect(x: 0, y: 0, width: 2560, height: 1080))
        let convexMiTV = QuartzDisplayDescriptor(id: 2, name: "Mi TV", frame: CGRect(x: -956, y: -1440, width: 2560, height: 1440))
        let convexASM = QuartzDisplayDescriptor(id: 3, name: "ASM", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
        let displays = [convexLG, convexMiTV, convexASM]
        let barriers = CursorBarrierGeometry.barriers(for: displays, length: 40)

        XCTAssertEqual(barriers.count, 8)
        XCTAssertEqual(try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: 20, y: 20), to: CGPoint(x: -20, y: 20),
            barriers: barriers.filter { $0.displayID == 1 }
        )).barrier.corner, .topLeft)
        XCTAssertEqual(try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: -20, y: 20), to: CGPoint(x: 20, y: 20),
            barriers: barriers.filter { $0.displayID == 3 }
        )).barrier.corner, .topRight)
        XCTAssertEqual(try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: -936, y: -20), to: CGPoint(x: -936, y: 20),
            barriers: barriers.filter { $0.displayID == 2 }
        )).barrier.corner, .bottomLeft)
        XCTAssertEqual(try XCTUnwrap(CursorBarrierGeometry.collision(
            from: CGPoint(x: 1584, y: -20), to: CGPoint(x: 1584, y: 20),
            barriers: barriers.filter { $0.displayID == 2 }
        )).barrier.corner, .bottomRight)

        XCTAssertNil(CursorBarrierGeometry.collision(
            from: CGPoint(x: -936, y: 20), to: CGPoint(x: -936, y: -20),
            barriers: barriers.filter { $0.displayID == 3 }
        ))
        XCTAssertNil(CursorBarrierGeometry.collision(
            from: CGPoint(x: 1584, y: 20), to: CGPoint(x: 1584, y: -20),
            barriers: barriers.filter { $0.displayID == 1 }
        ))
    }
}
