pub fn compress(comptime E: type, temp_allocator: std.mem.Allocator, w: *std.io.Writer, entries: []E, ) !void {
    // partition entries into groups having the same data value
    std.debug.assert(entries.len > 0);
    std.sort.pdq(E, entries, @as(?void, null), E.less_than);
    var d_partitions: std.ArrayList([]E) = .empty;
    defer d_partitions.deinit(temp_allocator);
    {
        var partition = try d_partitions.addOne(temp_allocator);
        partition.* = entries[0..1];
        var d = partition.*[0].data;
        for (entries[1..]) |entry| {
            if (d == entry.data) {
                partition.len += 1;
            } else {
                var new_partition = partition.*;
                new_partition.len += 1;
                new_partition = new_partition[new_partition.len-1..];
                partition = try d_partitions.addOne(temp_allocator);
                partition.* = new_partition;
                d = new_partition[0].data;
            }
        }
    }

    var addr_ranges: std.ArrayList(Range) = .empty;
    defer addr_ranges.deinit(temp_allocator);

    var d: E.Data = 0;
    for (d_partitions.items) |partition| {
        const d_delta = partition[0].data - d;
        d = partition[0].data;

        var a: E.Addr = 0;

        addr_ranges.clearRetainingCapacity();
        for (partition) |entry| {
            const a_delta = entry.addr - a;
            a = entry.addr +% 1;

            if (a_delta == 0 and addr_ranges.items.len > 0) {
                var last_addr_range = &addr_ranges.items[addr_ranges.items.len - 1];
                if (last_addr_range.count < std.math.maxInt(u32)) {
                    last_addr_range.count += 1;
                    continue;
                }
            }

            var new_addr_range = try addr_ranges.addOne(temp_allocator);
            new_addr_range.offset = a_delta;
            new_addr_range.count = 1;
        }

        const actual_addr_range_count = count: {
            var writer: Range_List_Writer = .{ .remaining = addr_ranges.items };
            var discard = std.io.Writer.Discarding.init(&.{});
            while (try writer.write(&discard.writer)) |_| {}
            break :count writer.actual_ranges_written;
        };

        var data_range_writer: Range_List_Writer = .{
            .remaining = &.{},
            .current = .{
                .offset = d_delta,
                .count = actual_addr_range_count,
            },
        };
        var addr_range_writer: Range_List_Writer = .{
            .remaining = addr_ranges.items,
        };

        while (try data_range_writer.write(w)) |num_addr_ranges_to_write| {
            for (0..num_addr_ranges_to_write) |_| {
                _ = try addr_range_writer.write(w);
            }
        }
    }
}

/// Ranges can be encoded with 1-6 bytes:
/// 7      0 15     8 23    16 31    24 39    32 47    40
/// -------- -------- -------- -------- -------- --------
/// ooooooo0                                                // Offset < 128           1 <= Count <= 1
/// ooonnn01 oooooooo                                       // Offset < 2048               Count in { 1, 2, 4, 8, 16, 32, 64, 256 }
/// ooooo011 nnnnnnnn                                       // Offset < 32            3 <= Count <= 258
/// nnnn0111 oooooooo nnoooooo                              // Offset < 16384         1 <= Count <= 64
/// nnn01111 nnnnnnnn oooooooo oooooooo                     // Offset < 65536         1 <= Count <= 2048
/// nnn11111 oooooooo oooooooo oooooooo                     // Offset < 16777216      1 <= Count <= 8
/// nnnnn011 00000001 nnnnnnnn oooooooo oooooooo            // Offset < 65536      2049 <= Count <= 10240
/// nnnnn011 00000101 nnnnnnnn oooooooo oooooooo oooooooo   // Offset < 16777216      9 <= Count <= 8200
/// ooooo011 00001101 nnnnnnnn nnnnnnnn nnnnnnnn nnnnnnnn   // Offset < 32                 Count < 2^32
/// nnnnn011 00011101 oooooooo oooooooo oooooooo oooooooo   // Offset < 2^32               Count <= 31
/// xxxxx011 00111101                                       // Unused
/// xxxxx011 11111101                                       // Unused
pub const Range = struct {
    offset: u32,
    count: u32,

    pub fn write(self: Range, w: *std.io.Writer) std.io.Writer.Error!u32 {
        const offset = self.offset;
        const count = self.count;

        if (offset < 128 and count == 1) {
            // ooooooo0
            try w.writeByte(bits.concat(.{
                @as(u1, 0),
                @as(u7, @intCast(offset)),
            }));

        } else if (offset < 2048 and (count == 256 or count <= 64 and @popCount(count) == 1)) {
            // ooonnn01 oooooooo
            const encoded_count: u3 = switch (count) {
                256 => 0,
                1 => 1,
                2 => 2,
                4 => 3,
                8 => 4,
                16 => 5,
                32 => 6,
                64 => 7,
                else => unreachable,
            };
            try w.writeByte(bits.concat(.{
                @as(u2, 1),
                encoded_count,
                @as(u3, @intCast(offset >> 8)),
            }));
            try w.writeByte(@truncate(offset));

        } else if (offset < 32 and 3 <= count and count <= 258) {
            // ooooo011 nnnnnnnn
            const encoded_count: u8 = @intCast(count - 3);
            try w.writeByte(bits.concat(.{
                @as(u3, 3),
                @as(u5, @intCast(offset)),
            }));
            try w.writeByte(encoded_count);

        } else if (offset < 16384 and 1 <= count and count <= 64) {
            // nnnn0111 oooooooo nnoooooo
            const encoded_count: u6 = @intCast(count - 1);
            try w.writeByte(bits.concat(.{
                @as(u4, 7),
                @as(u4, @truncate(encoded_count)),
            }));
            try w.writeByte(@truncate(offset));
            try w.writeByte(bits.concat(.{
                @as(u6, @intCast(offset >> 8)),
                @as(u2, @intCast(encoded_count >> 4)),
            }));

        } else if (offset < 65536 and 1 <= count and count <= 2048) {
            // nnn01111 nnnnnnnn oooooooo oooooooo
            const encoded_count: u11 = @intCast(count - 1);
            try w.writeByte(bits.concat(.{
                @as(u5, 15),
                @as(u3, @intCast(encoded_count >> 8)),
            }));
            try w.writeByte(@truncate(encoded_count));
            try w.writeByte(@truncate(offset));
            try w.writeByte(@intCast(offset >> 8));

        } else if (offset < 16777216 and 1 <= count and count <= 8) {
            // nnn11111 oooooooo oooooooo oooooooo
            const encoded_count: u11 = @intCast(count - 1);
            try w.writeByte(bits.concat(.{
                @as(u5, 31),
                @as(u3, @intCast(encoded_count)),
            }));
            try w.writeByte(@truncate(offset));
            try w.writeByte(@truncate(offset >> 8));
            try w.writeByte(@intCast(offset >> 16));

        } else if (offset < 65536 and 2049 <= count and count <= 10240) {
            // nnnnn011 00000001 nnnnnnnn oooooooo oooooooo
            const encoded_count: u13 = @intCast(count - 2049);
            try w.writeByte(bits.concat(.{
                @as(u3, 3),
                @as(u5, @intCast(encoded_count >> 8)),
            }));
            try w.writeByte(1);
            try w.writeByte(@truncate(encoded_count));
            try w.writeByte(@truncate(offset));
            try w.writeByte(@intCast(offset >> 8));

        } else if (offset < 16777216 and 9 <= count and count <= 8200) {
            // nnnnn011 00000101 nnnnnnnn oooooooo oooooooo oooooooo
            const encoded_count: u13 = @intCast(count - 9);
            try w.writeByte(bits.concat(.{
                @as(u3, 3),
                @as(u5, @intCast(encoded_count >> 8)),
            }));
            try w.writeByte(5);
            try w.writeByte(@truncate(encoded_count));
            try w.writeByte(@truncate(offset));
            try w.writeByte(@truncate(offset >> 8));
            try w.writeByte(@intCast(offset >> 16));

        } else if (offset < 32) {
            // ooooo011 00001101 nnnnnnnn nnnnnnnn nnnnnnnn nnnnnnnn
            try w.writeByte(bits.concat(.{
                @as(u3, 3),
                @as(u5, @intCast(offset)),
            }));
            try w.writeByte(13);
            try w.writeByte(@truncate(count));
            try w.writeByte(@truncate(count >> 8));
            try w.writeByte(@truncate(count >> 16));
            try w.writeByte(@intCast(count >> 24));

        } else if (count < 32) {
            // nnnnn011 00011101 oooooooo oooooooo oooooooo oooooooo
            try w.writeByte(bits.concat(.{
                @as(u3, 3),
                @as(u5, @intCast(count)),
            }));
            try w.writeByte(29);
            try w.writeByte(@truncate(offset));
            try w.writeByte(@truncate(offset >> 8));
            try w.writeByte(@truncate(offset >> 16));
            try w.writeByte(@intCast(offset >> 24));

        } else if (offset >= 16777216) {
            std.debug.assert(count > 31);
            return write(.{
                .offset = offset,
                .count = 31,
            }, w);
        } else if (offset >= 65536) {
            std.debug.assert(count > 8200);
            return write(.{
                .offset = offset,
                .count = 8,
            }, w);
        } else if (offset >= 16384) {
            std.debug.assert(count > 10240);
            return write(.{
                .offset = offset,
                .count = 2048,
            }, w);
        } else if (offset >= 2048) {
            std.debug.assert(count > 10240);
            return write(.{
                .offset = offset,
                .count = 64,
            }, w);
        } else {
            std.debug.assert(count > 10240);
            return write(.{
                .offset = offset,
                .count = 256,
            }, w);
        }

        return count;
    }
};

pub const Range_List_Writer = struct {
    remaining: []const Range,
    current: ?Range = null,
    actual_ranges_written: u32 = 0,

    pub fn write(self: *Range_List_Writer, w: *std.io.Writer) std.io.Writer.Error!?u32 {
        var current = self.current orelse next: {
            if (self.remaining.len == 0) return null;
            const next = self.remaining[0];
            self.current = next;
            self.remaining = self.remaining[1..];
            break :next next;
        };
        
        const count_written = try current.write(w);
        self.actual_ranges_written += 1;
        if (count_written == current.count) {
            self.current = null;
        } else {
            self.current = .{
                .offset = 0,
                .count = current.count - count_written,
            };
        }
        return count_written;
    }
};

pub fn Entry(comptime A: type, comptime D: type) type {
    return struct {
        const Addr = A;
        const Data = D;
        const Self = @This();

        addr: A,
        data: D,

        pub fn init(addr: A, data: D) Self {
            return .{ .addr = addr, .data = data };
        }

        pub fn less_than(_: ?void, e0: Self, e1: Self) bool {
            if (e0.data != e1.data) {
                return e0.data < e1.data;
            }

            return e0.addr < e1.addr;
        }
    };
}

const bits = @import("bits");
const std = @import("std");
