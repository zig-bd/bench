const std = @import("std");
const shared_mod = @import("shared_mod");

const zzz = @import("zzz");
const http = zzz.http;
const form = http.form;
const Secsock = zzz.Secsock;
const tardy = zzz.tardy;
const Tardy = tardy.Tardy(.auto);
const Route = http.Router.Route;

pub fn main(init: std.process.Init) !void {
    const host: []const u8 = "0.0.0.0";
    const port: u16 = shared_mod.port;

    const transport: Secsock.Unsecured = .empty;
    const tcp = try transport.tcp(init.gpa, .{
        .host = host,
        .port = port,
    });
    defer tcp.deinit(init.gpa);

    var router: http.Router = try .init(init.gpa, &.{
        Route.init("/httpz").get({}, httpz).layer(),
        Route.init("/api/users").get({}, users).layer(),
        Route.init("/form").post({}, formSubmit).layer(),
        Route.init("/upload").post({}, upload).layer(),
    }, .{});
    defer router.deinit(init.gpa);

    const EntryParams = struct {
        router: *const http.Router,
        tls: *const Secsock,
    };
    const params: EntryParams = .{
        .router = &router,
        .tls = &tcp,
    };

    var t: Tardy = try .init(init.gpa, init.io, .{
        .threading = .{ .multi = shared_mod.thread_count },
        .pooling = .static,
        .size_tasks_initial = shared_mod.worker_count,
    });
    defer t.deinit();

    try t.entry(
        params,
        struct {
            fn entry(rt: *tardy.Runtime, p: EntryParams) !void {
                var server: http.Server = .init(.{
                    .stack_size = .@"4MiB",
                    .socket_buffer_size = .@"2KiB",
                    .max_keepalive_count = null,
                    .max_connection_count = shared_mod.connection_count / shared_mod.thread_count,
                });
                defer server.deinit();
                try server.serve(rt, p.router, p.tls);
            }
        }.entry,
    );
}

fn httpz(ctx: *const http.Context, _: void) !http.Respond {
    return ctx.response.apply(.{
        .status = .OK,
        .mime = .TEXT,
        .body = "OK",
    });
}

fn users(ctx: *const http.Context, _: void) !http.Respond {
    const body = try std.json.Stringify.valueAlloc(ctx.arena, shared_mod.response.users, .{});
    return ctx.response.apply(.{
        .status = .OK,
        .mime = .JSON,
        .body = body,
    });
}

const FormFields = struct {
    name: []const u8,
    value: []const u8,
};

fn formSubmit(ctx: *const http.Context, _: void) !http.Respond {
    const fields = try form.Form(FormFields).parse(ctx);
    _ = fields;
    return ctx.response.apply(.{
        .status = .OK,
        .mime = .TEXT,
        .body = "OK",
    });
}

fn upload(ctx: *const http.Context, _: void) !http.Respond {
    const body = ctx.request.body orelse return error.BodyEmpty;
    if (std.mem.indexOf(u8, body, "filename=") == null) return error.MissingFile;
    return ctx.response.apply(.{
        .status = .OK,
        .mime = .TEXT,
        .body = "OK",
    });
}
