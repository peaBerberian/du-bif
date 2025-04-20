const std = @import("std");
const fs = std.fs;

// Enumerate formats that can be parsed here.
pub const ImageFormat = enum {
    Jpeg,
    Png,
};

// Metadata parsed from a given image.
pub const ImageInfo = struct {
    // The format parsed from that image.
    // This information is taken from magic numbers inside a file and is not assumed
    // from a file's path.
    format: ImageFormat,
    // Width in pixels of that image.
    width: u16,
    // Height in pixels of that image.
    height: u16,
};

pub const ImageParseError = error{
    UnhandledFormat,
    InvalidHeader,
    Truncated,
    MissingJpegSofMarker,
    ImageTooBig,
};

pub fn parseImageInfo(file_path: []const u8) !ImageInfo {
    const file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    var header_buffer: [8]u8 = undefined;
    const bytes_read = try file.read(header_buffer[0..8]);
    try file.seekTo(0);

    // Check for PNG signature
    const png_signature = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };
    if (bytes_read >= 8 and std.mem.eql(u8, header_buffer[0..8], &png_signature)) {
        return parsePngInfo(file);
    }

    // Check for JPEG signature
    if (bytes_read >= 2 and header_buffer[0] == 0xFF and header_buffer[1] == 0xD8) {
        return parseJpegInfo(file);
    }
    return ImageParseError.UnhandledFormat;
}

fn parseJpegInfo(jpeg_file: fs.File) !ImageInfo {
    var jpeg_head: [16]u8 = undefined;
    const bytes_read = try jpeg_file.read(jpeg_head[0..2]);
    if (bytes_read < 2 or jpeg_head[0] != 0xFF or jpeg_head[1] != 0xD8) {
        return ImageParseError.InvalidHeader;
    }

    var reader = jpeg_file.reader();
    while (true) {
        const marker_start = reader.readByte() catch return ImageParseError.Truncated;
        if (marker_start != 0xFF) continue;

        const marker_type = reader.readByte() catch return ImageParseError.Truncated;
        if (marker_type == 0xD9) return ImageParseError.MissingJpegSofMarker; // End of image

        // SOF markers (Start of Frame)
        if ((marker_type >= 0xC0 and marker_type <= 0xC3) or
            (marker_type >= 0xC5 and marker_type <= 0xC7) or
            (marker_type >= 0xC9 and marker_type <= 0xCB) or
            (marker_type >= 0xCD and marker_type <= 0xCF))
        {
            // Length (includes the length bytes but not the marker)
            var length_bytes: [2]u8 = undefined;
            _ = try reader.readAll(&length_bytes);

            // Skip precision byte
            _ = try reader.readByte();

            var height_bytes: [2]u8 = undefined;
            var width_bytes: [2]u8 = undefined;
            _ = try reader.readAll(&height_bytes);
            _ = try reader.readAll(&width_bytes);

            const height = @as(u16, height_bytes[0]) << 8 | height_bytes[1];
            const width = @as(u16, width_bytes[0]) << 8 | width_bytes[1];

            return ImageInfo{
                .format = .Jpeg,
                .width = width,
                .height = height,
            };
        } else {
            // Skip other markers
            var length_bytes: [2]u8 = undefined;
            _ = try reader.readAll(&length_bytes);
            const length = @as(u16, length_bytes[0]) << 8 | length_bytes[1];
            try reader.skipBytes(length - 2, .{});
        }
    }
    return ImageParseError.MissingJpegSofMarker;
}

fn parsePngInfo(file: fs.File) !ImageInfo {
    // Check PNG signature
    var signature: [8]u8 = undefined;
    _ = try file.read(&signature);
    const png_signature = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

    if (!std.mem.eql(u8, &signature, &png_signature)) {
        return ImageParseError.InvalidHeader;
    }

    var reader = file.reader();

    try file.seekTo(8); // Start after PNG signature

    var length_bytes: [4]u8 = undefined;
    _ = try reader.readAll(&length_bytes);
    var chunk_type: [4]u8 = undefined;
    _ = try reader.readAll(&chunk_type);

    if (!std.mem.eql(u8, &chunk_type, "IHDR")) {
        return ImageParseError.InvalidHeader;
    }

    // Read width
    var width_bytes: [4]u8 = undefined;
    _ = try reader.readAll(&width_bytes);
    const width = @as(u32, width_bytes[0]) << 24 |
        @as(u32, width_bytes[1]) << 16 |
        @as(u32, width_bytes[2]) << 8 |
        width_bytes[3];

    if (width > std.math.maxInt(u16)) return ImageParseError.ImageTooBig;
    const width_u16: u16 = @intCast(width);

    // Read height
    var height_bytes: [4]u8 = undefined;
    _ = try reader.readAll(&height_bytes);
    const height = @as(u32, height_bytes[0]) << 24 |
        @as(u32, height_bytes[1]) << 16 |
        @as(u32, height_bytes[2]) << 8 |
        height_bytes[3];

    if (height > std.math.maxInt(u16)) return ImageParseError.ImageTooBig;
    const height_u16: u16 = @intCast(height);

    return ImageInfo{
        .format = .Png,
        .width = width_u16,
        .height = height_u16,
    };
}

// Test utilities
fn createTestJpeg(path: []const u8) !void {
    // Create a simple JPEG file with SOI marker and SOF0 marker with dimensions 640x480
    const jpeg_data = [_]u8{
        // SOI marker
        0xFF, 0xD8,
        // APP0 marker (JFIF)
        0xFF, 0xE0,
        0x00, 0x10,
        'J',  'F',
        'I',  'F',
        0x00, 0x01,
        0x01, 0x00,
        0x00, 0x01,
        0x00, 0x01,
        0x00,
        0x00,
        // SOF0 marker (Start of Frame, baseline DCT)
        0xFF, 0xC0, 0x00, 0x11, // Length (17 bytes)
        0x08, // Precision (8 bits)
        0x01, 0xE0, // Height (480)
        0x02, 0x80, // Width (640)
        0x03, // Number of components
        0x01, 0x11, 0x00, // Component 1 parameters
        0x02, 0x11, 0x01, // Component 2 parameters
        0x03, 0x11, 0x01, // Component 3 parameters
    };
    const file = try fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(&jpeg_data);
}

fn createTestPng(path: []const u8) !void {
    // Create a simple PNG file with signature and IHDR chunk with dimensions 800x600
    const png_data = [_]u8{
        // PNG signature
        137,  80,   78,   71,   13,   10,   26,   10,
        // IHDR chunk length (13 bytes)
        0x00, 0x00, 0x00, 0x0D,
        // IHDR chunk type
        'I',  'H',  'D',  'R',
        // Width (800 = 0x00000320)
        0x00, 0x00, 0x03, 0x20,
        // Height (600 = 0x00000258)
        0x00, 0x00, 0x02, 0x58,
        // Bit depth, color type, compression method, filter method, interlace method
        0x08, 0x06, 0x00, 0x00, 0x00,
        // CRC (not accurate but just for test)
        0x00, 0x00, 0x00,
        0x00,
    };

    // Write the test PNG to a temporary file
    const file = try fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(&png_data);
}

const testing = std.testing;
test "parse JPEG info" {
    const path = "__TMP__jpeg.jpg";
    try createTestJpeg(path);
    defer fs.cwd().deleteFile(path) catch {};

    const info = try parseImageInfo(path);
    try testing.expectEqual(@as(u32, 640), info.width);
    try testing.expectEqual(@as(u32, 480), info.height);
    try testing.expectEqual(@as(ImageFormat, .Jpeg), info.format);
}

test "parse PNG info" {
    const path = "__TMP__png.png";
    try createTestPng(path);
    defer fs.cwd().deleteFile(path) catch {};

    const info = try parseImageInfo(path);
    try testing.expectEqual(@as(u32, 800), info.width);
    try testing.expectEqual(@as(u32, 600), info.height);
    try testing.expectEqual(@as(ImageFormat, .Png), info.format);
}

test "unknown image format" {
    const path = "__TMP__bad.jpg";
    const file = try fs.cwd().createFile(path, .{});
    defer fs.cwd().deleteFile(path) catch {};
    try file.writeAll("This is not an image file");
    file.close();

    const result = parseImageInfo(path);
    try testing.expectError(ImageParseError.UnhandledFormat, result);
}
