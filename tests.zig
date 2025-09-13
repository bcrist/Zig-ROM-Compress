test "rom_compress/decompress roundtripping" {
    const Entry = compress.Entry(u32, u16);

    const n = 65536;
    var raw_test_data = [_]u16 {0} ** n;
    var test_data = [_]Entry { .{ .addr = undefined, .data = undefined } } ** n;

    var rng = std.Random.Xoroshiro128.init(1234);
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

    const compressed = try compress.compress(Entry, std.testing.allocator, std.testing.allocator, &test_data);
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
    decompress.decompress(compressed, &ctx);
}

test "range roundtripping" {
    var data = std.io.Writer.Allocating.init(std.testing.allocator);
    defer data.deinit();

    const numbers = [_]u32 {
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
        31, 32, 33, 47, 48, 50,
        63, 64, 65, 100,
        127, 128, 129,
        255, 256, 258, 259,
        1000, 2000,
        2047, 2048,
        4095, 4096,
        8201, 8202,
        10000, 10241, 10242,
        16383, 16384,
        0xFFFF, 0x10000,
        0xFF_FFFF, 0x100_0000,
        0xF0F1_F2F3,
        0xFFFF_FFF0,
        0xFFFF_FFFF,
    };

    for (numbers) |offset| {
        for (numbers) |count| {
            data.clearRetainingCapacity();
            errdefer std.log.err("offset: {}  count: {}", .{ offset, count });

            {
                var range: compress.Range = .{
                    .offset = offset,
                    .count = count,
                };

                range.count -= try range.write(&data.writer);
                while (range.count > 0) {
                    range.offset = 0;
                    range.count -= try range.write(&data.writer);
                }
            }

            errdefer std.log.err("{any}", .{ data.writer.buffered() });

            var remaining = data.writer.buffered();
            const decompressed_range = decompress.Range.read(remaining);
            var decompressed: compress.Range = .{
                .offset = decompressed_range.offset,
                .count = decompressed_range.count,
            };
            remaining = remaining[decompressed_range.bytes..];

            while (remaining.len > 0) {
                const r = decompress.Range.read(remaining);
                if (decompressed.count > 0) {
                    errdefer std.log.err("{any}", .{ r });
                    try std.testing.expectEqual(0, r.offset);
                }
                decompressed.offset += r.offset;
                decompressed.count += r.count;
                remaining = remaining[r.bytes..];
            }

            try std.testing.expectEqual(offset, decompressed.offset);
            try std.testing.expectEqual(count, decompressed.count);
        }
    }
}

const compress = @import("rom_compress");
const decompress = @import("rom_decompress");
const std = @import("std");
