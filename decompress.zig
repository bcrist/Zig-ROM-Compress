const std = @import("std");
const bits = @import("bits");

pub fn decompress(input: []const u8, context: anytype) void {
    var data = input;

    var d: u32 = 0;
    var a: u32 = 0;

    while (data.len > 0) {
        var rec = Range.read(data);
        data = data[rec.bytes..];

        d += rec.offset;
        if (rec.offset > 0) {
            a = 0;
        }

        if (rec.count > 0) {
            context.data(d);

            var iter = RangeIterator {
                .data = data,
                .ranges_remaining = rec.count,
            };
            while (iter.next()) |range| {
                a +%= range.offset;
                var count = range.count;
                while (count > 0) : (count -= 1) {
                    context.address(a);
                    a += 1;
                }
            }

            data = iter.data;
        }
    }
}

const Range = struct {
    offset: u16,
    count: u16,
    bytes: u8,

    fn read(data: []const u8) Range {
        var r: Range = undefined;

        var initial = data[0];
        if ((initial & 1) == 0) {
            r.bytes = 1;
            r.count = 1;
            r.offset = @as(u7, @truncate(initial >> 1));
        } else if ((initial & 2) == 0) {
            var encoded_count: u3 = @truncate(initial >> 2);
            r.bytes = 2;
            r.count = if (encoded_count == 0) 256 else @as(u7, 1) << (encoded_count - 1);
            r.offset = bits.concat(.{
                @as(u3, @intCast(initial >> 5)),
                data[1],
            });
        } else { // (initial & 3) == 3
            r.bytes = 3;
            r.count = @as(u6, @truncate(initial >> 2));
            r.offset = bits.concat(.{
                data[1],
                data[2],
            });
        }

        // const print = @import("std").debug.print;

        // for (data[0..r.bytes]) |b| {
        //     print("{X:0>2} ", .{ b });
        // }
        // print(" = Range{} offset={} count={}\n", .{ r.bytes, r.offset, r.count });

        return r;
    }
};

const RangeIterator = struct {
    data: []const u8 = &[_]u8{},
    ranges_remaining: u16 = 0,

    fn next(self: *RangeIterator) ?Range {
        if (self.ranges_remaining == 0) return null;
        var r = Range.read(self.data);
        self.data = self.data[r.bytes..];
        self.ranges_remaining -= 1;
        return r;
    }
};
