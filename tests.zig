test "rom_compress/decompress roundtripping" {
    const Entry = @import("rom-compress").Entry(u32, u16);

    const n = 65536;
    var raw_test_data = [_]u16 {0} ** n;
    var test_data = [_]Entry { .{ .addr = undefined, .data = undefined } } ** n;

    var rng = std.rand.Xoroshiro128.init(1234);
    var rnd = rng.random();
    var i: usize = 0;
    while (i < test_data.len) : (i += 1) {
        const v = if (i < 32768) @as(u16, rnd.int(u4)) else rnd.int(u16);
        raw_test_data[i] = v;
        test_data[i] = .{
            .addr = @intCast(i),
            .data = v,
        };
    }

    var compressed = try compress(Entry, std.testing.allocator, std.testing.allocator, &test_data);
    defer std.testing.allocator.free(compressed);

    const Ctx = struct {
        test_data: []u16,
        d: u16 = undefined,

        const Self = @This();
        pub fn data(self: *Self, d: u32) void {
            //std.debug.print("Data: {}\n", .{ d });
            self.d = @intCast(d);
        }

        pub fn address(self: *Self, a: u32) void {
            //std.debug.print("Address: {}\n", .{ a });
            if (self.d != self.test_data[a]) {
                //std.debug.print("Test data: {any}\n", .{ self.test_data });
                std.debug.print("Address: {}  Found: {}  Expected:  {}\n", .{ a, self.d, self.test_data[a] });
                @panic("rom compress/decompress error!");
            }
        }
    };

    var ctx = Ctx { .test_data = &raw_test_data };
    decompress(compressed, &ctx);
}

const compress = @import("rom-compress").compress;
const decompress = @import("rom-decompress").decompress;
const std = @import("std");
