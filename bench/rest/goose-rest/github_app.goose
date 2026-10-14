// Tier R's handlers and its if chain, written by bench/rest/tiers/github_goose.py
// from github.txt; don't edit. Route n answers n and its parameters, separated
// by spaces. github_gen.goose's router calls the same handlers.
namespace app;

import std;
import http;
import rest;

fn answer(cx, n: i64, values: const u8[:][:]) {
    var b: u8[>..] = [];
    format(b, n);
    for v in values {
        b.push(' ');
        b.append(v);
    }
    rest::text(cx, 200, b);
}

fn r1(cx) { answer(cx, 1, []); }
fn r2(cx, id) { answer(cx, 2, [id]); }
fn r3(cx) { answer(cx, 3, []); }
fn r4(cx, id) { answer(cx, 4, [id]); }
fn r5(cx, client_id, access_token) { answer(cx, 5, [client_id, access_token]); }
fn r6(cx, client_id) { answer(cx, 6, [client_id]); }
fn r7(cx, client_id, access_token) { answer(cx, 7, [client_id, access_token]); }
fn r8(cx) { answer(cx, 8, []); }
fn r9(cx, owner, repo) { answer(cx, 9, [owner, repo]); }
fn r10(cx, owner, repo) { answer(cx, 10, [owner, repo]); }
fn r11(cx, org) { answer(cx, 11, [org]); }
fn r12(cx, user) { answer(cx, 12, [user]); }
fn r13(cx, user) { answer(cx, 13, [user]); }
fn r14(cx, user) { answer(cx, 14, [user]); }
fn r15(cx, user) { answer(cx, 15, [user]); }
fn r16(cx, user, org) { answer(cx, 16, [user, org]); }
fn r17(cx) { answer(cx, 17, []); }
fn r18(cx) { answer(cx, 18, []); }
fn r19(cx, owner, repo) { answer(cx, 19, [owner, repo]); }
fn r20(cx) { answer(cx, 20, []); }
fn r21(cx, owner, repo) { answer(cx, 21, [owner, repo]); }
fn r22(cx, id) { answer(cx, 22, [id]); }
fn r23(cx, id) { answer(cx, 23, [id]); }
fn r24(cx, id) { answer(cx, 24, [id]); }
fn r25(cx, id) { answer(cx, 25, [id]); }
fn r26(cx, owner, repo) { answer(cx, 26, [owner, repo]); }
fn r27(cx, user) { answer(cx, 27, [user]); }
fn r28(cx) { answer(cx, 28, []); }
fn r29(cx, owner, repo) { answer(cx, 29, [owner, repo]); }
fn r30(cx, owner, repo) { answer(cx, 30, [owner, repo]); }
fn r31(cx, owner, repo) { answer(cx, 31, [owner, repo]); }
fn r32(cx, owner, repo) { answer(cx, 32, [owner, repo]); }
fn r33(cx, user) { answer(cx, 33, [user]); }
fn r34(cx) { answer(cx, 34, []); }
fn r35(cx, owner, repo) { answer(cx, 35, [owner, repo]); }
fn r36(cx, owner, repo) { answer(cx, 36, [owner, repo]); }
fn r37(cx, owner, repo) { answer(cx, 37, [owner, repo]); }
fn r38(cx, owner, repo) { answer(cx, 38, [owner, repo]); }
fn r39(cx, owner, repo) { answer(cx, 39, [owner, repo]); }
fn r40(cx, owner, repo) { answer(cx, 40, [owner, repo]); }
fn r41(cx, user) { answer(cx, 41, [user]); }
fn r42(cx) { answer(cx, 42, []); }
fn r43(cx, id) { answer(cx, 43, [id]); }
fn r44(cx) { answer(cx, 44, []); }
fn r45(cx, id) { answer(cx, 45, [id]); }
fn r46(cx, id) { answer(cx, 46, [id]); }
fn r47(cx, id) { answer(cx, 47, [id]); }
fn r48(cx, id) { answer(cx, 48, [id]); }
fn r49(cx, id) { answer(cx, 49, [id]); }
fn r50(cx, owner, repo, sha) { answer(cx, 50, [owner, repo, sha]); }
fn r51(cx, owner, repo) { answer(cx, 51, [owner, repo]); }
fn r52(cx, owner, repo, sha) { answer(cx, 52, [owner, repo, sha]); }
fn r53(cx, owner, repo) { answer(cx, 53, [owner, repo]); }
fn r54(cx, owner, repo) { answer(cx, 54, [owner, repo]); }
fn r55(cx, owner, repo) { answer(cx, 55, [owner, repo]); }
fn r56(cx, owner, repo, sha) { answer(cx, 56, [owner, repo, sha]); }
fn r57(cx, owner, repo) { answer(cx, 57, [owner, repo]); }
fn r58(cx, owner, repo, sha) { answer(cx, 58, [owner, repo, sha]); }
fn r59(cx, owner, repo) { answer(cx, 59, [owner, repo]); }
fn r60(cx) { answer(cx, 60, []); }
fn r61(cx) { answer(cx, 61, []); }
fn r62(cx, org) { answer(cx, 62, [org]); }
fn r63(cx, owner, repo) { answer(cx, 63, [owner, repo]); }
fn r64(cx, owner, repo, number) { answer(cx, 64, [owner, repo, number]); }
fn r65(cx, owner, repo) { answer(cx, 65, [owner, repo]); }
fn r66(cx, owner, repo) { answer(cx, 66, [owner, repo]); }
fn r67(cx, owner, repo, assignee) { answer(cx, 67, [owner, repo, assignee]); }
fn r68(cx, owner, repo, number) { answer(cx, 68, [owner, repo, number]); }
fn r69(cx, owner, repo, number) { answer(cx, 69, [owner, repo, number]); }
fn r70(cx, owner, repo, number) { answer(cx, 70, [owner, repo, number]); }
fn r71(cx, owner, repo) { answer(cx, 71, [owner, repo]); }
fn r72(cx, owner, repo, name) { answer(cx, 72, [owner, repo, name]); }
fn r73(cx, owner, repo) { answer(cx, 73, [owner, repo]); }
fn r74(cx, owner, repo, name) { answer(cx, 74, [owner, repo, name]); }
fn r75(cx, owner, repo, number) { answer(cx, 75, [owner, repo, number]); }
fn r76(cx, owner, repo, number) { answer(cx, 76, [owner, repo, number]); }
fn r77(cx, owner, repo, number, name) { answer(cx, 77, [owner, repo, number, name]); }
fn r78(cx, owner, repo, number) { answer(cx, 78, [owner, repo, number]); }
fn r79(cx, owner, repo, number) { answer(cx, 79, [owner, repo, number]); }
fn r80(cx, owner, repo, number) { answer(cx, 80, [owner, repo, number]); }
fn r81(cx, owner, repo) { answer(cx, 81, [owner, repo]); }
fn r82(cx, owner, repo, number) { answer(cx, 82, [owner, repo, number]); }
fn r83(cx, owner, repo) { answer(cx, 83, [owner, repo]); }
fn r84(cx, owner, repo, number) { answer(cx, 84, [owner, repo, number]); }
fn r85(cx) { answer(cx, 85, []); }
fn r86(cx) { answer(cx, 86, []); }
fn r87(cx, name) { answer(cx, 87, [name]); }
fn r88(cx) { answer(cx, 88, []); }
fn r89(cx) { answer(cx, 89, []); }
fn r90(cx) { answer(cx, 90, []); }
fn r91(cx) { answer(cx, 91, []); }
fn r92(cx, user) { answer(cx, 92, [user]); }
fn r93(cx) { answer(cx, 93, []); }
fn r94(cx, org) { answer(cx, 94, [org]); }
fn r95(cx, org) { answer(cx, 95, [org]); }
fn r96(cx, org, user) { answer(cx, 96, [org, user]); }
fn r97(cx, org, user) { answer(cx, 97, [org, user]); }
fn r98(cx, org) { answer(cx, 98, [org]); }
fn r99(cx, org, user) { answer(cx, 99, [org, user]); }
fn r100(cx, org, user) { answer(cx, 100, [org, user]); }
fn r101(cx, org, user) { answer(cx, 101, [org, user]); }
fn r102(cx, org) { answer(cx, 102, [org]); }
fn r103(cx, id) { answer(cx, 103, [id]); }
fn r104(cx, org) { answer(cx, 104, [org]); }
fn r105(cx, id) { answer(cx, 105, [id]); }
fn r106(cx, id) { answer(cx, 106, [id]); }
fn r107(cx, id, user) { answer(cx, 107, [id, user]); }
fn r108(cx, id, user) { answer(cx, 108, [id, user]); }
fn r109(cx, id, user) { answer(cx, 109, [id, user]); }
fn r110(cx, id) { answer(cx, 110, [id]); }
fn r111(cx, id, owner, repo) { answer(cx, 111, [id, owner, repo]); }
fn r112(cx, id, owner, repo) { answer(cx, 112, [id, owner, repo]); }
fn r113(cx, id, owner, repo) { answer(cx, 113, [id, owner, repo]); }
fn r114(cx) { answer(cx, 114, []); }
fn r115(cx, owner, repo) { answer(cx, 115, [owner, repo]); }
fn r116(cx, owner, repo, number) { answer(cx, 116, [owner, repo, number]); }
fn r117(cx, owner, repo) { answer(cx, 117, [owner, repo]); }
fn r118(cx, owner, repo, number) { answer(cx, 118, [owner, repo, number]); }
fn r119(cx, owner, repo, number) { answer(cx, 119, [owner, repo, number]); }
fn r120(cx, owner, repo, number) { answer(cx, 120, [owner, repo, number]); }
fn r121(cx, owner, repo, number) { answer(cx, 121, [owner, repo, number]); }
fn r122(cx, owner, repo, number) { answer(cx, 122, [owner, repo, number]); }
fn r123(cx, owner, repo, number) { answer(cx, 123, [owner, repo, number]); }
fn r124(cx) { answer(cx, 124, []); }
fn r125(cx, user) { answer(cx, 125, [user]); }
fn r126(cx, org) { answer(cx, 126, [org]); }
fn r127(cx) { answer(cx, 127, []); }
fn r128(cx) { answer(cx, 128, []); }
fn r129(cx, org) { answer(cx, 129, [org]); }
fn r130(cx, owner, repo) { answer(cx, 130, [owner, repo]); }
fn r131(cx, owner, repo) { answer(cx, 131, [owner, repo]); }
fn r132(cx, owner, repo) { answer(cx, 132, [owner, repo]); }
fn r133(cx, owner, repo) { answer(cx, 133, [owner, repo]); }
fn r134(cx, owner, repo) { answer(cx, 134, [owner, repo]); }
fn r135(cx, owner, repo) { answer(cx, 135, [owner, repo]); }
fn r136(cx, owner, repo, branch) { answer(cx, 136, [owner, repo, branch]); }
fn r137(cx, owner, repo) { answer(cx, 137, [owner, repo]); }
fn r138(cx, owner, repo) { answer(cx, 138, [owner, repo]); }
fn r139(cx, owner, repo, user) { answer(cx, 139, [owner, repo, user]); }
fn r140(cx, owner, repo, user) { answer(cx, 140, [owner, repo, user]); }
fn r141(cx, owner, repo, user) { answer(cx, 141, [owner, repo, user]); }
fn r142(cx, owner, repo) { answer(cx, 142, [owner, repo]); }
fn r143(cx, owner, repo, sha) { answer(cx, 143, [owner, repo, sha]); }
fn r144(cx, owner, repo, sha) { answer(cx, 144, [owner, repo, sha]); }
fn r145(cx, owner, repo, id) { answer(cx, 145, [owner, repo, id]); }
fn r146(cx, owner, repo, id) { answer(cx, 146, [owner, repo, id]); }
fn r147(cx, owner, repo) { answer(cx, 147, [owner, repo]); }
fn r148(cx, owner, repo, sha) { answer(cx, 148, [owner, repo, sha]); }
fn r149(cx, owner, repo) { answer(cx, 149, [owner, repo]); }
fn r150(cx, owner, repo) { answer(cx, 150, [owner, repo]); }
fn r151(cx, owner, repo, id) { answer(cx, 151, [owner, repo, id]); }
fn r152(cx, owner, repo) { answer(cx, 152, [owner, repo]); }
fn r153(cx, owner, repo, id) { answer(cx, 153, [owner, repo, id]); }
fn r154(cx, owner, repo) { answer(cx, 154, [owner, repo]); }
fn r155(cx, owner, repo, id) { answer(cx, 155, [owner, repo, id]); }
fn r156(cx, owner, repo, id) { answer(cx, 156, [owner, repo, id]); }
fn r157(cx, owner, repo) { answer(cx, 157, [owner, repo]); }
fn r158(cx, owner, repo) { answer(cx, 158, [owner, repo]); }
fn r159(cx, owner, repo) { answer(cx, 159, [owner, repo]); }
fn r160(cx, owner, repo, id) { answer(cx, 160, [owner, repo, id]); }
fn r161(cx, owner, repo) { answer(cx, 161, [owner, repo]); }
fn r162(cx, owner, repo, id) { answer(cx, 162, [owner, repo, id]); }
fn r163(cx, owner, repo, id) { answer(cx, 163, [owner, repo, id]); }
fn r164(cx, owner, repo) { answer(cx, 164, [owner, repo]); }
fn r165(cx, owner, repo) { answer(cx, 165, [owner, repo]); }
fn r166(cx, owner, repo, id) { answer(cx, 166, [owner, repo, id]); }
fn r167(cx, owner, repo) { answer(cx, 167, [owner, repo]); }
fn r168(cx, owner, repo, id) { answer(cx, 168, [owner, repo, id]); }
fn r169(cx, owner, repo, id) { answer(cx, 169, [owner, repo, id]); }
fn r170(cx, owner, repo) { answer(cx, 170, [owner, repo]); }
fn r171(cx, owner, repo) { answer(cx, 171, [owner, repo]); }
fn r172(cx, owner, repo) { answer(cx, 172, [owner, repo]); }
fn r173(cx, owner, repo) { answer(cx, 173, [owner, repo]); }
fn r174(cx, owner, repo) { answer(cx, 174, [owner, repo]); }
fn r175(cx, owner, repo, ref) { answer(cx, 175, [owner, repo, ref]); }
fn r176(cx, owner, repo, ref) { answer(cx, 176, [owner, repo, ref]); }
fn r177(cx) { answer(cx, 177, []); }
fn r178(cx) { answer(cx, 178, []); }
fn r179(cx) { answer(cx, 179, []); }
fn r180(cx) { answer(cx, 180, []); }
fn r181(cx, owner, repository, state_, keyword) { answer(cx, 181, [owner, repository, state_, keyword]); }
fn r182(cx, keyword) { answer(cx, 182, [keyword]); }
fn r183(cx, keyword) { answer(cx, 183, [keyword]); }
fn r184(cx, email) { answer(cx, 184, [email]); }
fn r185(cx, user) { answer(cx, 185, [user]); }
fn r186(cx) { answer(cx, 186, []); }
fn r187(cx) { answer(cx, 187, []); }
fn r188(cx) { answer(cx, 188, []); }
fn r189(cx) { answer(cx, 189, []); }
fn r190(cx) { answer(cx, 190, []); }
fn r191(cx, user) { answer(cx, 191, [user]); }
fn r192(cx) { answer(cx, 192, []); }
fn r193(cx, user) { answer(cx, 193, [user]); }
fn r194(cx) { answer(cx, 194, []); }
fn r195(cx, user) { answer(cx, 195, [user]); }
fn r196(cx, user, target_user) { answer(cx, 196, [user, target_user]); }
fn r197(cx, user) { answer(cx, 197, [user]); }
fn r198(cx, user) { answer(cx, 198, [user]); }
fn r199(cx, user) { answer(cx, 199, [user]); }
fn r200(cx) { answer(cx, 200, []); }
fn r201(cx, id) { answer(cx, 201, [id]); }
fn r202(cx) { answer(cx, 202, []); }
fn r203(cx, id) { answer(cx, 203, [id]); }

// The routes as an if chain, in github.txt's order.
fn chain(cx) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/authorizations") {
        r1(cx);
    } else if http::on(r, "GET", "/authorizations/:id") {
        r2(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/authorizations") {
        r3(cx);
    } else if http::on(r, "DELETE", "/authorizations/:id") {
        r4(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/applications/:client_id/tokens/:access_token") {
        r5(cx, rest::param(cx, r, "client_id"), rest::param(cx, r, "access_token"));
    } else if http::on(r, "DELETE", "/applications/:client_id/tokens") {
        r6(cx, rest::param(cx, r, "client_id"));
    } else if http::on(r, "DELETE", "/applications/:client_id/tokens/:access_token") {
        r7(cx, rest::param(cx, r, "client_id"), rest::param(cx, r, "access_token"));
    } else if http::on(r, "GET", "/events") {
        r8(cx);
    } else if http::on(r, "GET", "/repos/:owner/:repo/events") {
        r9(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/networks/:owner/:repo/events") {
        r10(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/orgs/:org/events") {
        r11(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/users/:user/received_events") {
        r12(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/received_events/public") {
        r13(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/events") {
        r14(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/events/public") {
        r15(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/events/orgs/:org") {
        r16(cx, rest::param(cx, r, "user"), rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/feeds") {
        r17(cx);
    } else if http::on(r, "GET", "/notifications") {
        r18(cx);
    } else if http::on(r, "GET", "/repos/:owner/:repo/notifications") {
        r19(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/notifications") {
        r20(cx);
    } else if http::on(r, "PUT", "/repos/:owner/:repo/notifications") {
        r21(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/notifications/threads/:id") {
        r22(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/notifications/threads/:id/subscription") {
        r23(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "PUT", "/notifications/threads/:id/subscription") {
        r24(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/notifications/threads/:id/subscription") {
        r25(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stargazers") {
        r26(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/users/:user/starred") {
        r27(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/starred") {
        r28(cx);
    } else if http::on(r, "GET", "/user/starred/:owner/:repo") {
        r29(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/user/starred/:owner/:repo") {
        r30(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/user/starred/:owner/:repo") {
        r31(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/subscribers") {
        r32(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/users/:user/subscriptions") {
        r33(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/subscriptions") {
        r34(cx);
    } else if http::on(r, "GET", "/repos/:owner/:repo/subscription") {
        r35(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/subscription") {
        r36(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/subscription") {
        r37(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/user/subscriptions/:owner/:repo") {
        r38(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/user/subscriptions/:owner/:repo") {
        r39(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/user/subscriptions/:owner/:repo") {
        r40(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/users/:user/gists") {
        r41(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/gists") {
        r42(cx);
    } else if http::on(r, "GET", "/gists/:id") {
        r43(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/gists") {
        r44(cx);
    } else if http::on(r, "PUT", "/gists/:id/star") {
        r45(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/gists/:id/star") {
        r46(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/gists/:id/star") {
        r47(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/gists/:id/forks") {
        r48(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/gists/:id") {
        r49(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/blobs/:sha") {
        r50(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/blobs") {
        r51(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/commits/:sha") {
        r52(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/commits") {
        r53(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/refs") {
        r54(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/refs") {
        r55(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/tags/:sha") {
        r56(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/tags") {
        r57(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/trees/:sha") {
        r58(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/trees") {
        r59(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/issues") {
        r60(cx);
    } else if http::on(r, "GET", "/user/issues") {
        r61(cx);
    } else if http::on(r, "GET", "/orgs/:org/issues") {
        r62(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues") {
        r63(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number") {
        r64(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/issues") {
        r65(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/assignees") {
        r66(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/assignees/:assignee") {
        r67(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "assignee"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number/comments") {
        r68(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/issues/:number/comments") {
        r69(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number/events") {
        r70(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/labels") {
        r71(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/labels/:name") {
        r72(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "name"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/labels") {
        r73(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/labels/:name") {
        r74(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "name"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number/labels") {
        r75(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/issues/:number/labels") {
        r76(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/issues/:number/labels/:name") {
        r77(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"), rest::param(cx, r, "name"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/issues/:number/labels") {
        r78(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/issues/:number/labels") {
        r79(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/milestones/:number/labels") {
        r80(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/milestones") {
        r81(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/milestones/:number") {
        r82(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/milestones") {
        r83(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/milestones/:number") {
        r84(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/emojis") {
        r85(cx);
    } else if http::on(r, "GET", "/gitignore/templates") {
        r86(cx);
    } else if http::on(r, "GET", "/gitignore/templates/:name") {
        r87(cx, rest::param(cx, r, "name"));
    } else if http::on(r, "POST", "/markdown") {
        r88(cx);
    } else if http::on(r, "POST", "/markdown/raw") {
        r89(cx);
    } else if http::on(r, "GET", "/meta") {
        r90(cx);
    } else if http::on(r, "GET", "/rate_limit") {
        r91(cx);
    } else if http::on(r, "GET", "/users/:user/orgs") {
        r92(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/orgs") {
        r93(cx);
    } else if http::on(r, "GET", "/orgs/:org") {
        r94(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/orgs/:org/members") {
        r95(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/orgs/:org/members/:user") {
        r96(cx, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/orgs/:org/members/:user") {
        r97(cx, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/orgs/:org/public_members") {
        r98(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/orgs/:org/public_members/:user") {
        r99(cx, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "PUT", "/orgs/:org/public_members/:user") {
        r100(cx, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/orgs/:org/public_members/:user") {
        r101(cx, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/orgs/:org/teams") {
        r102(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/teams/:id") {
        r103(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/orgs/:org/teams") {
        r104(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "DELETE", "/teams/:id") {
        r105(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/teams/:id/members") {
        r106(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/teams/:id/members/:user") {
        r107(cx, rest::param(cx, r, "id"), rest::param(cx, r, "user"));
    } else if http::on(r, "PUT", "/teams/:id/members/:user") {
        r108(cx, rest::param(cx, r, "id"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/teams/:id/members/:user") {
        r109(cx, rest::param(cx, r, "id"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/teams/:id/repos") {
        r110(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/teams/:id/repos/:owner/:repo") {
        r111(cx, rest::param(cx, r, "id"), rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/teams/:id/repos/:owner/:repo") {
        r112(cx, rest::param(cx, r, "id"), rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/teams/:id/repos/:owner/:repo") {
        r113(cx, rest::param(cx, r, "id"), rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/user/teams") {
        r114(cx);
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls") {
        r115(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number") {
        r116(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/pulls") {
        r117(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/commits") {
        r118(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/files") {
        r119(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/merge") {
        r120(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/pulls/:number/merge") {
        r121(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/comments") {
        r122(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/pulls/:number/comments") {
        r123(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/user/repos") {
        r124(cx);
    } else if http::on(r, "GET", "/users/:user/repos") {
        r125(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/orgs/:org/repos") {
        r126(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/repositories") {
        r127(cx);
    } else if http::on(r, "POST", "/user/repos") {
        r128(cx);
    } else if http::on(r, "POST", "/orgs/:org/repos") {
        r129(cx, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/repos/:owner/:repo") {
        r130(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/contributors") {
        r131(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/languages") {
        r132(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/teams") {
        r133(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/tags") {
        r134(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/branches") {
        r135(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/branches/:branch") {
        r136(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "branch"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo") {
        r137(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/collaborators") {
        r138(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/collaborators/:user") {
        r139(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "user"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/collaborators/:user") {
        r140(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/collaborators/:user") {
        r141(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/comments") {
        r142(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/commits/:sha/comments") {
        r143(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/commits/:sha/comments") {
        r144(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/comments/:id") {
        r145(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/comments/:id") {
        r146(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/commits") {
        r147(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/commits/:sha") {
        r148(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/readme") {
        r149(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/keys") {
        r150(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/keys/:id") {
        r151(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/keys") {
        r152(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/keys/:id") {
        r153(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/downloads") {
        r154(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/downloads/:id") {
        r155(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/downloads/:id") {
        r156(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/forks") {
        r157(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/forks") {
        r158(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/hooks") {
        r159(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/hooks/:id") {
        r160(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/hooks") {
        r161(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/hooks/:id/tests") {
        r162(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/hooks/:id") {
        r163(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/merges") {
        r164(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/releases") {
        r165(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/releases/:id") {
        r166(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/releases") {
        r167(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/releases/:id") {
        r168(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/releases/:id/assets") {
        r169(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/contributors") {
        r170(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/commit_activity") {
        r171(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/code_frequency") {
        r172(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/participation") {
        r173(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/punch_card") {
        r174(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/statuses/:ref") {
        r175(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "ref"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/statuses/:ref") {
        r176(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "ref"));
    } else if http::on(r, "GET", "/search/repositories") {
        r177(cx);
    } else if http::on(r, "GET", "/search/code") {
        r178(cx);
    } else if http::on(r, "GET", "/search/issues") {
        r179(cx);
    } else if http::on(r, "GET", "/search/users") {
        r180(cx);
    } else if http::on(r, "GET", "/legacy/issues/search/:owner/:repository/:state/:keyword") {
        r181(cx, rest::param(cx, r, "owner"), rest::param(cx, r, "repository"), rest::param(cx, r, "state"), rest::param(cx, r, "keyword"));
    } else if http::on(r, "GET", "/legacy/repos/search/:keyword") {
        r182(cx, rest::param(cx, r, "keyword"));
    } else if http::on(r, "GET", "/legacy/user/search/:keyword") {
        r183(cx, rest::param(cx, r, "keyword"));
    } else if http::on(r, "GET", "/legacy/user/email/:email") {
        r184(cx, rest::param(cx, r, "email"));
    } else if http::on(r, "GET", "/users/:user") {
        r185(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user") {
        r186(cx);
    } else if http::on(r, "GET", "/users") {
        r187(cx);
    } else if http::on(r, "GET", "/user/emails") {
        r188(cx);
    } else if http::on(r, "POST", "/user/emails") {
        r189(cx);
    } else if http::on(r, "DELETE", "/user/emails") {
        r190(cx);
    } else if http::on(r, "GET", "/users/:user/followers") {
        r191(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/followers") {
        r192(cx);
    } else if http::on(r, "GET", "/users/:user/following") {
        r193(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/following") {
        r194(cx);
    } else if http::on(r, "GET", "/user/following/:user") {
        r195(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/following/:target_user") {
        r196(cx, rest::param(cx, r, "user"), rest::param(cx, r, "target_user"));
    } else if http::on(r, "PUT", "/user/following/:user") {
        r197(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/user/following/:user") {
        r198(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/keys") {
        r199(cx, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/keys") {
        r200(cx);
    } else if http::on(r, "GET", "/user/keys/:id") {
        r201(cx, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/user/keys") {
        r202(cx);
    } else if http::on(r, "DELETE", "/user/keys/:id") {
        r203(cx, rest::param(cx, r, "id"));
    } else {
        rest::otherwise(cx, r);
    }
}
