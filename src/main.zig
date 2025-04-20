const std = @import("std");
const image_parsing = @import("image_parsing.zig");
const fs = std.fs;

pub fn main() !void {
    // TODO:
    // var separation_ms: ?u32 = undefined;

    var input_dir: ?[]const u8 = null;
    var output_filename: ?[]const u8 = null;

    var args = std.process.args();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--") == true) {
            break;
        } else if (std.mem.eql(u8, arg, "-i") == true or std.mem.eql(u8, arg, "--input") == true) {
            const dir_arg = args.next();
            if (dir_arg) |dir_val| {
                if (input_dir != null) {
                    return error.TooManyInputDirs;
                }
                input_dir = dir_val[0.. :0];
            } else {
                return error.MissingDirArgument;
            }
        } else if (std.mem.eql(u8, arg, "-o") == true or std.mem.eql(u8, arg, "--output") == true) {
            const file_output = args.next();
            if (file_output) |output_val| {
                if (output_filename != null) {
                    return error.TooManyInputDirs;
                }
                output_filename = output_val[0.. :0];
            } else {
                return error.MissingOutputArgument;
            }
            // } else if (std.mem.eql(u8, arg, "-s") == true or std.mem.eql(u8, arg, "--separation") == true) {
            //     const separation = args.next();
            //     if (separation) |*val| {
            //         separation_ms = try std.fmt.parseInt(u32, val[0.. :0], 10);
            //     } else {
            //         return error.MissingSeparationArgument;
        } else if (std.mem.eql(u8, arg, "-h") == true or std.mem.eql(u8, arg, "--help") == true) {
            // TODO: output help
            return;
            // } else {
            //     return error.UnknownArgument{arg};
        }
    }

    return createBif(.{
        .input_dir = input_dir orelse return error.MissingInputDirectoryFlag,
        .output_filename = output_filename orelse "./output.bif",
    });
}

pub const BifCreationArguments = struct {
    /// The input directory where input thumbnails are.
    input_dir: []const u8,

    // The path to the outputed bif.
    output_filename: []const u8,
};

pub fn createBif(arg: BifCreationArguments) !void {
    // XXx TODO:
    const input_files = [_][]const u8{
        "input-tests/Tears_of_Steel_1080p_0001.jpg",
        "input-tests/Tears_of_Steel_1080p_0002.jpg",
        "input-tests/Tears_of_Steel_1080p_0003.jpg",
    };

    const out_file = try std.fs.cwd().createFile(arg.output_filename, .{});

    if (input_files.len > std.math.maxInt(u32)) {
        try std.io.getStdErr().writer().print("Error: too many input files: {d}", .{input_files.len});
        return error.TooManyFiles;
    }
    const num_files: u32 = @intCast(input_files.len);
    var header_buf = [_]u8{
        0x89, 'B', 'I', 'F', '\r', '\n', 0x01, 'a', '\n',

        // version
        0,    0,   0,   0,

        // number of files
          0,    0,    0,    0,

        // framewise separation
        // TODO:
          0,
        0,    0,   0,

        // format
        // TODO:
          0,   0,    0,    0,

        // width
           0,   0,

        // height
        0,    0,

        // aspect ratio
          0,   0,

        // isVoD
          1,
    };
    comptime var current_offset = 13;

    writeInt(u32, num_files, header_buf[current_offset .. current_offset + 4]); // set number of files
    current_offset += 4;
    writeInt(u32, 16, header_buf[current_offset .. current_offset + 4]); // set framewise separation
    current_offset += 4;
    writeStr("jpeg", header_buf[current_offset .. current_offset + 4]); // set format
    current_offset += 4;

    _ = try image_parsing.parseImageInfo("./input-tests/Tears_of_Steel_1080p_0001.jpg");

    // @memcpy(header_buf[21..25], "jpeg"); // Set format

    // writeStr(4, header_buf[21..25], "jpeg"); // set framewise separatin

    // writeU32ToBuf(header_buf[13..17], num_files); // set number of files
    // writeU32ToBuf(header_buf[17..21], 16); // set framewise separation

    // write the whole header to the output file
    try out_file.writeAll(&header_buf);

    logSizeOf([*]u16);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello {d}, {d}, {d}, {d}, {d}!\n", .{ num_files, header_buf[13], header_buf[14], header_buf[15], header_buf[16] });

    try stdout.print("Hello2 {d}, {d}, {d}, {d}!\n", .{ header_buf[21], header_buf[22], header_buf[23], header_buf[24] });
    const buffer_size = 4096;
    var buffer: [buffer_size]u8 = undefined;

    for (input_files) |input_file| {
        const in_file = try fs.cwd().openFile(input_file, .{});
        defer in_file.close();

        while (true) {
            const bytes_read = try in_file.read(buffer[0..]);
            if (bytes_read == 0) break;

            try out_file.writeAll(buffer[0..bytes_read]);
        }
    }
}

fn writeInt(
    comptime T: type,
    value: T,
    buffer: *[@divExact(@typeInfo(T).Int.bits, 8)]u8,
) void {
    if (T == u64 or T == u32 or T == u16 or T == u8) {
        std.mem.writeInt(T, buffer, value, .big);
    } else if (T == []const u8) {} else {
        comptime unreachable;
    }
}

fn writeStr(
    comptime str: []const u8,
    buffer: *[str.len]u8,
) void {
    @memcpy(buffer, str); // Set format
}

fn logSizeOf(comptime T: type) void {
    std.debug.print("aa {}", .{@sizeOf(T)});
}
