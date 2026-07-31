-- Berry Framework Automated Unit Test Suite

local passes = 0
local fails = 0

local function assert_equal(actual, expected, testName)
    if actual == expected then
        passes = passes + 1
        print(string.format("  [PASS] %s", testName))
    else
        fails = fails + 1
        print(string.format("  [FAIL] %s - Expected %s, got %s", testName, tostring(expected), tostring(actual)))
    end
end

print("=== Starting Berry Framework Unit Tests ===")

-- Test 1: Permission Hierarchy
local levels = BerryConstants.PermissionHierarchy
assert_equal(levels.user < levels.administrator, true, "User permission < Admin permission")
assert_equal(levels.administrator < levels.owner, true, "Admin permission < Owner permission")

-- Test 2: Types Validation
assert_equal(BerryTypes.IsPositiveNumber(500), true, "Positive number check for 500")
assert_equal(BerryTypes.IsPositiveNumber(-500), false, "Positive number check for -500")
assert_equal(BerryTypes.IsPositiveNumber("500"), false, "Positive number check for string '500'")

-- Test 3: Distance calculation
local d = Berry.Utils.CalculateDistance({x=0,y=0,z=0}, {x=3,y=4,z=0})
assert_equal(d, 5.0, "3D Pythagoras distance test")

print(string.format("=== Unit Tests Summary: %d Passed, %d Failed ===", passes, fails))
