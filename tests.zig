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

    var w = std.io.Writer.Allocating.init(std.testing.allocator);
    defer w.deinit();

    try compress.compress(Entry, std.testing.allocator, &w.writer, &test_data);

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
    decompress.decompress(w.written(), &ctx);
}

test "dump" {
    const Entry = compress.Entry(u32, u16);

    const n = 64;
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

    var w = std.io.Writer.Allocating.init(std.testing.allocator);
    defer w.deinit();

    try compress.compress(Entry, std.testing.allocator, &w.writer, &test_data);

    var d = std.io.Writer.Allocating.init(std.testing.allocator);
    defer d.deinit();

    try decompress.dump(w.written(), &d.writer);

    try std.testing.expectEqualStrings(
		\\DR2[0:3 (3)]
		\\  D: 0x00000000
		\\    AR1[3:4 (1)]               A: [0x00000003:0x00000004]
		\\    AR1[29:30 (1)]             A: [0x00000020:0x00000021]
		\\    AR1[16:17 (1)]             A: [0x00000030:0x00000031]
		\\DR2[1:4 (3)]
		\\  D: 0x00000001
		\\    AR1[15:16 (1)]             A: [0x0000000F:0x00000010]
		\\    AR1[10:11 (1)]             A: [0x00000019:0x0000001A]
		\\    AR1[35:36 (1)]             A: [0x0000003C:0x0000003D]
		\\DR2[1:5 (4)]
		\\  D: 0x00000002
		\\    AR1[5:6 (1)]               A: [0x00000005:0x00000006]
		\\    AR1[10:11 (1)]             A: [0x0000000F:0x00000010]
		\\    AR1[17:18 (1)]             A: [0x00000020:0x00000021]
		\\    AR1[19:20 (1)]             A: [0x00000033:0x00000034]
		\\DR2[1:5 (4)]
		\\  D: 0x00000003
		\\    AR1[8:9 (1)]               A: [0x00000008:0x00000009]
		\\    AR1[4:5 (1)]               A: [0x0000000C:0x0000000D]
		\\    AR1[23:24 (1)]             A: [0x00000023:0x00000024]
		\\    AR2[1:4 (3)]               A: [0x00000024:0x00000027]
		\\DR2[1:3 (2)]
		\\  D: 0x00000004
		\\    AR1[52:53 (1)]             A: [0x00000034:0x00000035]
		\\    AR1[10:11 (1)]             A: [0x0000003E:0x0000003F]
		\\DR2[1:5 (4)]
		\\  D: 0x00000005
		\\    AR1[31:32 (1)]             A: [0x0000001F:0x00000020]
		\\    AR1[6:7 (1)]               A: [0x00000025:0x00000026]
		\\    AR1[14:15 (1)]             A: [0x00000033:0x00000034]
		\\    AR1[4:5 (1)]               A: [0x00000037:0x00000038]
		\\DR2[1:5 (4)]
		\\  D: 0x00000006
		\\    AR1[12:13 (1)]             A: [0x0000000C:0x0000000D]
		\\    AR1[4:5 (1)]               A: [0x00000010:0x00000011]
		\\    AR1[18:19 (1)]             A: [0x00000022:0x00000023]
		\\    AR1[8:9 (1)]               A: [0x0000002A:0x0000002B]
		\\DR2[1:6 (5)]
		\\  D: 0x00000007
		\\    AR1[1:2 (1)]               A: [0x00000001:0x00000002]
		\\    AR1[19:20 (1)]             A: [0x00000014:0x00000015]
		\\    AR1[2:3 (1)]               A: [0x00000016:0x00000017]
		\\    AR1[2:3 (1)]               A: [0x00000018:0x00000019]
		\\    AR1[20:21 (1)]             A: [0x0000002C:0x0000002D]
		\\DR2[1:6 (5)]
		\\  D: 0x00000008
		\\    AR1[2:3 (1)]               A: [0x00000002:0x00000003]
		\\    AR1[4:5 (1)]               A: [0x00000006:0x00000007]
		\\    AR1[20:21 (1)]             A: [0x0000001A:0x0000001B]
		\\    AR1[20:21 (1)]             A: [0x0000002E:0x0000002F]
		\\    AR1[7:8 (1)]               A: [0x00000035:0x00000036]
		\\DR2[1:6 (5)]
		\\  D: 0x00000009
		\\    AR1[23:24 (1)]             A: [0x00000017:0x00000018]
		\\    AR1[1:2 (1)]               A: [0x00000018:0x00000019]
		\\    AR1[20:21 (1)]             A: [0x0000002C:0x0000002D]
		\\    AR1[4:5 (1)]               A: [0x00000030:0x00000031]
		\\    AR1[3:4 (1)]               A: [0x00000033:0x00000034]
		\\DR2[1:5 (4)]
		\\  D: 0x0000000A
		\\    AR1[9:10 (1)]              A: [0x00000009:0x0000000A]
		\\    AR1[12:13 (1)]             A: [0x00000015:0x00000016]
		\\    AR1[24:25 (1)]             A: [0x0000002D:0x0000002E]
		\\    AR1[13:14 (1)]             A: [0x0000003A:0x0000003B]
		\\DR2[1:7 (6)]
		\\  D: 0x0000000B
		\\    AR1[4:5 (1)]               A: [0x00000004:0x00000005]
		\\    AR1[13:14 (1)]             A: [0x00000011:0x00000012]
		\\    AR1[13:14 (1)]             A: [0x0000001E:0x0000001F]
		\\    AR1[2:3 (1)]               A: [0x00000020:0x00000021]
		\\    AR1[7:8 (1)]               A: [0x00000027:0x00000028]
		\\    AR1[16:17 (1)]             A: [0x00000037:0x00000038]
		\\DR2[1:3 (2)]
		\\  D: 0x0000000C
		\\    AR1[11:12 (1)]             A: [0x0000000B:0x0000000C]
		\\    AR1[44:45 (1)]             A: [0x00000037:0x00000038]
		\\DR2[1:4 (3)]
		\\  D: 0x0000000D
		\\    AR1[6:7 (1)]               A: [0x00000006:0x00000007]
		\\    AR2[22:24 (2)]             A: [0x0000001C:0x0000001E]
		\\    AR1[13:14 (1)]             A: [0x00000029:0x0000002A]
		\\DR2[1:6 (5)]
		\\  D: 0x0000000E
		\\    AR1[10:11 (1)]             A: [0x0000000A:0x0000000B]
		\\    AR1[3:4 (1)]               A: [0x0000000D:0x0000000E]
		\\    AR1[5:6 (1)]               A: [0x00000012:0x00000013]
		\\    AR1[21:22 (1)]             A: [0x00000027:0x00000028]
		\\    AR1[16:17 (1)]             A: [0x00000037:0x00000038]
		\\DR2[1:3 (2)]
		\\  D: 0x0000000F
		\\    AR1[0:1 (1)]               A: [0x00000000:0x00000001]
		\\    AR1[18:19 (1)]             A: [0x00000012:0x00000013]
		\\
        , d.written());
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
