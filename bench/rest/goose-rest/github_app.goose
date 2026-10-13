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

fn r1(cx, state) { answer(cx, 1, []); }
fn r2(cx, state, id) { answer(cx, 2, [id]); }
fn r3(cx, state) { answer(cx, 3, []); }
fn r4(cx, state, id) { answer(cx, 4, [id]); }
fn r5(cx, state, client_id, access_token) { answer(cx, 5, [client_id, access_token]); }
fn r6(cx, state, client_id) { answer(cx, 6, [client_id]); }
fn r7(cx, state, client_id, access_token) { answer(cx, 7, [client_id, access_token]); }
fn r8(cx, state) { answer(cx, 8, []); }
fn r9(cx, state, owner, repo) { answer(cx, 9, [owner, repo]); }
fn r10(cx, state, owner, repo) { answer(cx, 10, [owner, repo]); }
fn r11(cx, state, org) { answer(cx, 11, [org]); }
fn r12(cx, state, user) { answer(cx, 12, [user]); }
fn r13(cx, state, user) { answer(cx, 13, [user]); }
fn r14(cx, state, user) { answer(cx, 14, [user]); }
fn r15(cx, state, user) { answer(cx, 15, [user]); }
fn r16(cx, state, user, org) { answer(cx, 16, [user, org]); }
fn r17(cx, state) { answer(cx, 17, []); }
fn r18(cx, state) { answer(cx, 18, []); }
fn r19(cx, state, owner, repo) { answer(cx, 19, [owner, repo]); }
fn r20(cx, state) { answer(cx, 20, []); }
fn r21(cx, state, owner, repo) { answer(cx, 21, [owner, repo]); }
fn r22(cx, state, id) { answer(cx, 22, [id]); }
fn r23(cx, state, id) { answer(cx, 23, [id]); }
fn r24(cx, state, id) { answer(cx, 24, [id]); }
fn r25(cx, state, id) { answer(cx, 25, [id]); }
fn r26(cx, state, owner, repo) { answer(cx, 26, [owner, repo]); }
fn r27(cx, state, user) { answer(cx, 27, [user]); }
fn r28(cx, state) { answer(cx, 28, []); }
fn r29(cx, state, owner, repo) { answer(cx, 29, [owner, repo]); }
fn r30(cx, state, owner, repo) { answer(cx, 30, [owner, repo]); }
fn r31(cx, state, owner, repo) { answer(cx, 31, [owner, repo]); }
fn r32(cx, state, owner, repo) { answer(cx, 32, [owner, repo]); }
fn r33(cx, state, user) { answer(cx, 33, [user]); }
fn r34(cx, state) { answer(cx, 34, []); }
fn r35(cx, state, owner, repo) { answer(cx, 35, [owner, repo]); }
fn r36(cx, state, owner, repo) { answer(cx, 36, [owner, repo]); }
fn r37(cx, state, owner, repo) { answer(cx, 37, [owner, repo]); }
fn r38(cx, state, owner, repo) { answer(cx, 38, [owner, repo]); }
fn r39(cx, state, owner, repo) { answer(cx, 39, [owner, repo]); }
fn r40(cx, state, owner, repo) { answer(cx, 40, [owner, repo]); }
fn r41(cx, state, user) { answer(cx, 41, [user]); }
fn r42(cx, state) { answer(cx, 42, []); }
fn r43(cx, state, id) { answer(cx, 43, [id]); }
fn r44(cx, state) { answer(cx, 44, []); }
fn r45(cx, state, id) { answer(cx, 45, [id]); }
fn r46(cx, state, id) { answer(cx, 46, [id]); }
fn r47(cx, state, id) { answer(cx, 47, [id]); }
fn r48(cx, state, id) { answer(cx, 48, [id]); }
fn r49(cx, state, id) { answer(cx, 49, [id]); }
fn r50(cx, state, owner, repo, sha) { answer(cx, 50, [owner, repo, sha]); }
fn r51(cx, state, owner, repo) { answer(cx, 51, [owner, repo]); }
fn r52(cx, state, owner, repo, sha) { answer(cx, 52, [owner, repo, sha]); }
fn r53(cx, state, owner, repo) { answer(cx, 53, [owner, repo]); }
fn r54(cx, state, owner, repo) { answer(cx, 54, [owner, repo]); }
fn r55(cx, state, owner, repo) { answer(cx, 55, [owner, repo]); }
fn r56(cx, state, owner, repo, sha) { answer(cx, 56, [owner, repo, sha]); }
fn r57(cx, state, owner, repo) { answer(cx, 57, [owner, repo]); }
fn r58(cx, state, owner, repo, sha) { answer(cx, 58, [owner, repo, sha]); }
fn r59(cx, state, owner, repo) { answer(cx, 59, [owner, repo]); }
fn r60(cx, state) { answer(cx, 60, []); }
fn r61(cx, state) { answer(cx, 61, []); }
fn r62(cx, state, org) { answer(cx, 62, [org]); }
fn r63(cx, state, owner, repo) { answer(cx, 63, [owner, repo]); }
fn r64(cx, state, owner, repo, number) { answer(cx, 64, [owner, repo, number]); }
fn r65(cx, state, owner, repo) { answer(cx, 65, [owner, repo]); }
fn r66(cx, state, owner, repo) { answer(cx, 66, [owner, repo]); }
fn r67(cx, state, owner, repo, assignee) { answer(cx, 67, [owner, repo, assignee]); }
fn r68(cx, state, owner, repo, number) { answer(cx, 68, [owner, repo, number]); }
fn r69(cx, state, owner, repo, number) { answer(cx, 69, [owner, repo, number]); }
fn r70(cx, state, owner, repo, number) { answer(cx, 70, [owner, repo, number]); }
fn r71(cx, state, owner, repo) { answer(cx, 71, [owner, repo]); }
fn r72(cx, state, owner, repo, name) { answer(cx, 72, [owner, repo, name]); }
fn r73(cx, state, owner, repo) { answer(cx, 73, [owner, repo]); }
fn r74(cx, state, owner, repo, name) { answer(cx, 74, [owner, repo, name]); }
fn r75(cx, state, owner, repo, number) { answer(cx, 75, [owner, repo, number]); }
fn r76(cx, state, owner, repo, number) { answer(cx, 76, [owner, repo, number]); }
fn r77(cx, state, owner, repo, number, name) { answer(cx, 77, [owner, repo, number, name]); }
fn r78(cx, state, owner, repo, number) { answer(cx, 78, [owner, repo, number]); }
fn r79(cx, state, owner, repo, number) { answer(cx, 79, [owner, repo, number]); }
fn r80(cx, state, owner, repo, number) { answer(cx, 80, [owner, repo, number]); }
fn r81(cx, state, owner, repo) { answer(cx, 81, [owner, repo]); }
fn r82(cx, state, owner, repo, number) { answer(cx, 82, [owner, repo, number]); }
fn r83(cx, state, owner, repo) { answer(cx, 83, [owner, repo]); }
fn r84(cx, state, owner, repo, number) { answer(cx, 84, [owner, repo, number]); }
fn r85(cx, state) { answer(cx, 85, []); }
fn r86(cx, state) { answer(cx, 86, []); }
fn r87(cx, state, name) { answer(cx, 87, [name]); }
fn r88(cx, state) { answer(cx, 88, []); }
fn r89(cx, state) { answer(cx, 89, []); }
fn r90(cx, state) { answer(cx, 90, []); }
fn r91(cx, state) { answer(cx, 91, []); }
fn r92(cx, state, user) { answer(cx, 92, [user]); }
fn r93(cx, state) { answer(cx, 93, []); }
fn r94(cx, state, org) { answer(cx, 94, [org]); }
fn r95(cx, state, org) { answer(cx, 95, [org]); }
fn r96(cx, state, org, user) { answer(cx, 96, [org, user]); }
fn r97(cx, state, org, user) { answer(cx, 97, [org, user]); }
fn r98(cx, state, org) { answer(cx, 98, [org]); }
fn r99(cx, state, org, user) { answer(cx, 99, [org, user]); }
fn r100(cx, state, org, user) { answer(cx, 100, [org, user]); }
fn r101(cx, state, org, user) { answer(cx, 101, [org, user]); }
fn r102(cx, state, org) { answer(cx, 102, [org]); }
fn r103(cx, state, id) { answer(cx, 103, [id]); }
fn r104(cx, state, org) { answer(cx, 104, [org]); }
fn r105(cx, state, id) { answer(cx, 105, [id]); }
fn r106(cx, state, id) { answer(cx, 106, [id]); }
fn r107(cx, state, id, user) { answer(cx, 107, [id, user]); }
fn r108(cx, state, id, user) { answer(cx, 108, [id, user]); }
fn r109(cx, state, id, user) { answer(cx, 109, [id, user]); }
fn r110(cx, state, id) { answer(cx, 110, [id]); }
fn r111(cx, state, id, owner, repo) { answer(cx, 111, [id, owner, repo]); }
fn r112(cx, state, id, owner, repo) { answer(cx, 112, [id, owner, repo]); }
fn r113(cx, state, id, owner, repo) { answer(cx, 113, [id, owner, repo]); }
fn r114(cx, state) { answer(cx, 114, []); }
fn r115(cx, state, owner, repo) { answer(cx, 115, [owner, repo]); }
fn r116(cx, state, owner, repo, number) { answer(cx, 116, [owner, repo, number]); }
fn r117(cx, state, owner, repo) { answer(cx, 117, [owner, repo]); }
fn r118(cx, state, owner, repo, number) { answer(cx, 118, [owner, repo, number]); }
fn r119(cx, state, owner, repo, number) { answer(cx, 119, [owner, repo, number]); }
fn r120(cx, state, owner, repo, number) { answer(cx, 120, [owner, repo, number]); }
fn r121(cx, state, owner, repo, number) { answer(cx, 121, [owner, repo, number]); }
fn r122(cx, state, owner, repo, number) { answer(cx, 122, [owner, repo, number]); }
fn r123(cx, state, owner, repo, number) { answer(cx, 123, [owner, repo, number]); }
fn r124(cx, state) { answer(cx, 124, []); }
fn r125(cx, state, user) { answer(cx, 125, [user]); }
fn r126(cx, state, org) { answer(cx, 126, [org]); }
fn r127(cx, state) { answer(cx, 127, []); }
fn r128(cx, state) { answer(cx, 128, []); }
fn r129(cx, state, org) { answer(cx, 129, [org]); }
fn r130(cx, state, owner, repo) { answer(cx, 130, [owner, repo]); }
fn r131(cx, state, owner, repo) { answer(cx, 131, [owner, repo]); }
fn r132(cx, state, owner, repo) { answer(cx, 132, [owner, repo]); }
fn r133(cx, state, owner, repo) { answer(cx, 133, [owner, repo]); }
fn r134(cx, state, owner, repo) { answer(cx, 134, [owner, repo]); }
fn r135(cx, state, owner, repo) { answer(cx, 135, [owner, repo]); }
fn r136(cx, state, owner, repo, branch) { answer(cx, 136, [owner, repo, branch]); }
fn r137(cx, state, owner, repo) { answer(cx, 137, [owner, repo]); }
fn r138(cx, state, owner, repo) { answer(cx, 138, [owner, repo]); }
fn r139(cx, state, owner, repo, user) { answer(cx, 139, [owner, repo, user]); }
fn r140(cx, state, owner, repo, user) { answer(cx, 140, [owner, repo, user]); }
fn r141(cx, state, owner, repo, user) { answer(cx, 141, [owner, repo, user]); }
fn r142(cx, state, owner, repo) { answer(cx, 142, [owner, repo]); }
fn r143(cx, state, owner, repo, sha) { answer(cx, 143, [owner, repo, sha]); }
fn r144(cx, state, owner, repo, sha) { answer(cx, 144, [owner, repo, sha]); }
fn r145(cx, state, owner, repo, id) { answer(cx, 145, [owner, repo, id]); }
fn r146(cx, state, owner, repo, id) { answer(cx, 146, [owner, repo, id]); }
fn r147(cx, state, owner, repo) { answer(cx, 147, [owner, repo]); }
fn r148(cx, state, owner, repo, sha) { answer(cx, 148, [owner, repo, sha]); }
fn r149(cx, state, owner, repo) { answer(cx, 149, [owner, repo]); }
fn r150(cx, state, owner, repo) { answer(cx, 150, [owner, repo]); }
fn r151(cx, state, owner, repo, id) { answer(cx, 151, [owner, repo, id]); }
fn r152(cx, state, owner, repo) { answer(cx, 152, [owner, repo]); }
fn r153(cx, state, owner, repo, id) { answer(cx, 153, [owner, repo, id]); }
fn r154(cx, state, owner, repo) { answer(cx, 154, [owner, repo]); }
fn r155(cx, state, owner, repo, id) { answer(cx, 155, [owner, repo, id]); }
fn r156(cx, state, owner, repo, id) { answer(cx, 156, [owner, repo, id]); }
fn r157(cx, state, owner, repo) { answer(cx, 157, [owner, repo]); }
fn r158(cx, state, owner, repo) { answer(cx, 158, [owner, repo]); }
fn r159(cx, state, owner, repo) { answer(cx, 159, [owner, repo]); }
fn r160(cx, state, owner, repo, id) { answer(cx, 160, [owner, repo, id]); }
fn r161(cx, state, owner, repo) { answer(cx, 161, [owner, repo]); }
fn r162(cx, state, owner, repo, id) { answer(cx, 162, [owner, repo, id]); }
fn r163(cx, state, owner, repo, id) { answer(cx, 163, [owner, repo, id]); }
fn r164(cx, state, owner, repo) { answer(cx, 164, [owner, repo]); }
fn r165(cx, state, owner, repo) { answer(cx, 165, [owner, repo]); }
fn r166(cx, state, owner, repo, id) { answer(cx, 166, [owner, repo, id]); }
fn r167(cx, state, owner, repo) { answer(cx, 167, [owner, repo]); }
fn r168(cx, state, owner, repo, id) { answer(cx, 168, [owner, repo, id]); }
fn r169(cx, state, owner, repo, id) { answer(cx, 169, [owner, repo, id]); }
fn r170(cx, state, owner, repo) { answer(cx, 170, [owner, repo]); }
fn r171(cx, state, owner, repo) { answer(cx, 171, [owner, repo]); }
fn r172(cx, state, owner, repo) { answer(cx, 172, [owner, repo]); }
fn r173(cx, state, owner, repo) { answer(cx, 173, [owner, repo]); }
fn r174(cx, state, owner, repo) { answer(cx, 174, [owner, repo]); }
fn r175(cx, state, owner, repo, ref) { answer(cx, 175, [owner, repo, ref]); }
fn r176(cx, state, owner, repo, ref) { answer(cx, 176, [owner, repo, ref]); }
fn r177(cx, state) { answer(cx, 177, []); }
fn r178(cx, state) { answer(cx, 178, []); }
fn r179(cx, state) { answer(cx, 179, []); }
fn r180(cx, state) { answer(cx, 180, []); }
fn r181(cx, state, owner, repository, state_, keyword) { answer(cx, 181, [owner, repository, state_, keyword]); }
fn r182(cx, state, keyword) { answer(cx, 182, [keyword]); }
fn r183(cx, state, keyword) { answer(cx, 183, [keyword]); }
fn r184(cx, state, email) { answer(cx, 184, [email]); }
fn r185(cx, state, user) { answer(cx, 185, [user]); }
fn r186(cx, state) { answer(cx, 186, []); }
fn r187(cx, state) { answer(cx, 187, []); }
fn r188(cx, state) { answer(cx, 188, []); }
fn r189(cx, state) { answer(cx, 189, []); }
fn r190(cx, state) { answer(cx, 190, []); }
fn r191(cx, state, user) { answer(cx, 191, [user]); }
fn r192(cx, state) { answer(cx, 192, []); }
fn r193(cx, state, user) { answer(cx, 193, [user]); }
fn r194(cx, state) { answer(cx, 194, []); }
fn r195(cx, state, user) { answer(cx, 195, [user]); }
fn r196(cx, state, user, target_user) { answer(cx, 196, [user, target_user]); }
fn r197(cx, state, user) { answer(cx, 197, [user]); }
fn r198(cx, state, user) { answer(cx, 198, [user]); }
fn r199(cx, state, user) { answer(cx, 199, [user]); }
fn r200(cx, state) { answer(cx, 200, []); }
fn r201(cx, state, id) { answer(cx, 201, [id]); }
fn r202(cx, state) { answer(cx, 202, []); }
fn r203(cx, state, id) { answer(cx, 203, [id]); }

// The routes as an if chain, in github.txt's order.
fn chain(cx, state) {
    var r = http::router(cx.req);
    if http::on(r, "GET", "/authorizations") {
        r1(cx, state);
    } else if http::on(r, "GET", "/authorizations/:id") {
        r2(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/authorizations") {
        r3(cx, state);
    } else if http::on(r, "DELETE", "/authorizations/:id") {
        r4(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/applications/:client_id/tokens/:access_token") {
        r5(cx, state, rest::param(cx, r, "client_id"), rest::param(cx, r, "access_token"));
    } else if http::on(r, "DELETE", "/applications/:client_id/tokens") {
        r6(cx, state, rest::param(cx, r, "client_id"));
    } else if http::on(r, "DELETE", "/applications/:client_id/tokens/:access_token") {
        r7(cx, state, rest::param(cx, r, "client_id"), rest::param(cx, r, "access_token"));
    } else if http::on(r, "GET", "/events") {
        r8(cx, state);
    } else if http::on(r, "GET", "/repos/:owner/:repo/events") {
        r9(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/networks/:owner/:repo/events") {
        r10(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/orgs/:org/events") {
        r11(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/users/:user/received_events") {
        r12(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/received_events/public") {
        r13(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/events") {
        r14(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/events/public") {
        r15(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/events/orgs/:org") {
        r16(cx, state, rest::param(cx, r, "user"), rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/feeds") {
        r17(cx, state);
    } else if http::on(r, "GET", "/notifications") {
        r18(cx, state);
    } else if http::on(r, "GET", "/repos/:owner/:repo/notifications") {
        r19(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/notifications") {
        r20(cx, state);
    } else if http::on(r, "PUT", "/repos/:owner/:repo/notifications") {
        r21(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/notifications/threads/:id") {
        r22(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/notifications/threads/:id/subscription") {
        r23(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "PUT", "/notifications/threads/:id/subscription") {
        r24(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/notifications/threads/:id/subscription") {
        r25(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stargazers") {
        r26(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/users/:user/starred") {
        r27(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/starred") {
        r28(cx, state);
    } else if http::on(r, "GET", "/user/starred/:owner/:repo") {
        r29(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/user/starred/:owner/:repo") {
        r30(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/user/starred/:owner/:repo") {
        r31(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/subscribers") {
        r32(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/users/:user/subscriptions") {
        r33(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/subscriptions") {
        r34(cx, state);
    } else if http::on(r, "GET", "/repos/:owner/:repo/subscription") {
        r35(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/subscription") {
        r36(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/subscription") {
        r37(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/user/subscriptions/:owner/:repo") {
        r38(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/user/subscriptions/:owner/:repo") {
        r39(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/user/subscriptions/:owner/:repo") {
        r40(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/users/:user/gists") {
        r41(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/gists") {
        r42(cx, state);
    } else if http::on(r, "GET", "/gists/:id") {
        r43(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/gists") {
        r44(cx, state);
    } else if http::on(r, "PUT", "/gists/:id/star") {
        r45(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/gists/:id/star") {
        r46(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/gists/:id/star") {
        r47(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/gists/:id/forks") {
        r48(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/gists/:id") {
        r49(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/blobs/:sha") {
        r50(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/blobs") {
        r51(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/commits/:sha") {
        r52(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/commits") {
        r53(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/refs") {
        r54(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/refs") {
        r55(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/tags/:sha") {
        r56(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/tags") {
        r57(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/git/trees/:sha") {
        r58(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/git/trees") {
        r59(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/issues") {
        r60(cx, state);
    } else if http::on(r, "GET", "/user/issues") {
        r61(cx, state);
    } else if http::on(r, "GET", "/orgs/:org/issues") {
        r62(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues") {
        r63(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number") {
        r64(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/issues") {
        r65(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/assignees") {
        r66(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/assignees/:assignee") {
        r67(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "assignee"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number/comments") {
        r68(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/issues/:number/comments") {
        r69(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number/events") {
        r70(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/labels") {
        r71(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/labels/:name") {
        r72(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "name"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/labels") {
        r73(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/labels/:name") {
        r74(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "name"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/issues/:number/labels") {
        r75(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/issues/:number/labels") {
        r76(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/issues/:number/labels/:name") {
        r77(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"), rest::param(cx, r, "name"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/issues/:number/labels") {
        r78(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/issues/:number/labels") {
        r79(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/milestones/:number/labels") {
        r80(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/milestones") {
        r81(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/milestones/:number") {
        r82(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/milestones") {
        r83(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/milestones/:number") {
        r84(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/emojis") {
        r85(cx, state);
    } else if http::on(r, "GET", "/gitignore/templates") {
        r86(cx, state);
    } else if http::on(r, "GET", "/gitignore/templates/:name") {
        r87(cx, state, rest::param(cx, r, "name"));
    } else if http::on(r, "POST", "/markdown") {
        r88(cx, state);
    } else if http::on(r, "POST", "/markdown/raw") {
        r89(cx, state);
    } else if http::on(r, "GET", "/meta") {
        r90(cx, state);
    } else if http::on(r, "GET", "/rate_limit") {
        r91(cx, state);
    } else if http::on(r, "GET", "/users/:user/orgs") {
        r92(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/orgs") {
        r93(cx, state);
    } else if http::on(r, "GET", "/orgs/:org") {
        r94(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/orgs/:org/members") {
        r95(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/orgs/:org/members/:user") {
        r96(cx, state, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/orgs/:org/members/:user") {
        r97(cx, state, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/orgs/:org/public_members") {
        r98(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/orgs/:org/public_members/:user") {
        r99(cx, state, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "PUT", "/orgs/:org/public_members/:user") {
        r100(cx, state, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/orgs/:org/public_members/:user") {
        r101(cx, state, rest::param(cx, r, "org"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/orgs/:org/teams") {
        r102(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/teams/:id") {
        r103(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/orgs/:org/teams") {
        r104(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "DELETE", "/teams/:id") {
        r105(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/teams/:id/members") {
        r106(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/teams/:id/members/:user") {
        r107(cx, state, rest::param(cx, r, "id"), rest::param(cx, r, "user"));
    } else if http::on(r, "PUT", "/teams/:id/members/:user") {
        r108(cx, state, rest::param(cx, r, "id"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/teams/:id/members/:user") {
        r109(cx, state, rest::param(cx, r, "id"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/teams/:id/repos") {
        r110(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/teams/:id/repos/:owner/:repo") {
        r111(cx, state, rest::param(cx, r, "id"), rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "PUT", "/teams/:id/repos/:owner/:repo") {
        r112(cx, state, rest::param(cx, r, "id"), rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/teams/:id/repos/:owner/:repo") {
        r113(cx, state, rest::param(cx, r, "id"), rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/user/teams") {
        r114(cx, state);
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls") {
        r115(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number") {
        r116(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/pulls") {
        r117(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/commits") {
        r118(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/files") {
        r119(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/merge") {
        r120(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/pulls/:number/merge") {
        r121(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/pulls/:number/comments") {
        r122(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/pulls/:number/comments") {
        r123(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "number"));
    } else if http::on(r, "GET", "/user/repos") {
        r124(cx, state);
    } else if http::on(r, "GET", "/users/:user/repos") {
        r125(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/orgs/:org/repos") {
        r126(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/repositories") {
        r127(cx, state);
    } else if http::on(r, "POST", "/user/repos") {
        r128(cx, state);
    } else if http::on(r, "POST", "/orgs/:org/repos") {
        r129(cx, state, rest::param(cx, r, "org"));
    } else if http::on(r, "GET", "/repos/:owner/:repo") {
        r130(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/contributors") {
        r131(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/languages") {
        r132(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/teams") {
        r133(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/tags") {
        r134(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/branches") {
        r135(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/branches/:branch") {
        r136(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "branch"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo") {
        r137(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/collaborators") {
        r138(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/collaborators/:user") {
        r139(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "user"));
    } else if http::on(r, "PUT", "/repos/:owner/:repo/collaborators/:user") {
        r140(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/collaborators/:user") {
        r141(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/comments") {
        r142(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/commits/:sha/comments") {
        r143(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/commits/:sha/comments") {
        r144(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/comments/:id") {
        r145(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/comments/:id") {
        r146(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/commits") {
        r147(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/commits/:sha") {
        r148(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "sha"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/readme") {
        r149(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/keys") {
        r150(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/keys/:id") {
        r151(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/keys") {
        r152(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/keys/:id") {
        r153(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/downloads") {
        r154(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/downloads/:id") {
        r155(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/downloads/:id") {
        r156(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/forks") {
        r157(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/forks") {
        r158(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/hooks") {
        r159(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/hooks/:id") {
        r160(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/hooks") {
        r161(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/hooks/:id/tests") {
        r162(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/hooks/:id") {
        r163(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/merges") {
        r164(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/releases") {
        r165(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/releases/:id") {
        r166(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/releases") {
        r167(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "DELETE", "/repos/:owner/:repo/releases/:id") {
        r168(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/releases/:id/assets") {
        r169(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "id"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/contributors") {
        r170(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/commit_activity") {
        r171(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/code_frequency") {
        r172(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/participation") {
        r173(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/stats/punch_card") {
        r174(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"));
    } else if http::on(r, "GET", "/repos/:owner/:repo/statuses/:ref") {
        r175(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "ref"));
    } else if http::on(r, "POST", "/repos/:owner/:repo/statuses/:ref") {
        r176(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repo"), rest::param(cx, r, "ref"));
    } else if http::on(r, "GET", "/search/repositories") {
        r177(cx, state);
    } else if http::on(r, "GET", "/search/code") {
        r178(cx, state);
    } else if http::on(r, "GET", "/search/issues") {
        r179(cx, state);
    } else if http::on(r, "GET", "/search/users") {
        r180(cx, state);
    } else if http::on(r, "GET", "/legacy/issues/search/:owner/:repository/:state/:keyword") {
        r181(cx, state, rest::param(cx, r, "owner"), rest::param(cx, r, "repository"), rest::param(cx, r, "state"), rest::param(cx, r, "keyword"));
    } else if http::on(r, "GET", "/legacy/repos/search/:keyword") {
        r182(cx, state, rest::param(cx, r, "keyword"));
    } else if http::on(r, "GET", "/legacy/user/search/:keyword") {
        r183(cx, state, rest::param(cx, r, "keyword"));
    } else if http::on(r, "GET", "/legacy/user/email/:email") {
        r184(cx, state, rest::param(cx, r, "email"));
    } else if http::on(r, "GET", "/users/:user") {
        r185(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user") {
        r186(cx, state);
    } else if http::on(r, "GET", "/users") {
        r187(cx, state);
    } else if http::on(r, "GET", "/user/emails") {
        r188(cx, state);
    } else if http::on(r, "POST", "/user/emails") {
        r189(cx, state);
    } else if http::on(r, "DELETE", "/user/emails") {
        r190(cx, state);
    } else if http::on(r, "GET", "/users/:user/followers") {
        r191(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/followers") {
        r192(cx, state);
    } else if http::on(r, "GET", "/users/:user/following") {
        r193(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/following") {
        r194(cx, state);
    } else if http::on(r, "GET", "/user/following/:user") {
        r195(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/following/:target_user") {
        r196(cx, state, rest::param(cx, r, "user"), rest::param(cx, r, "target_user"));
    } else if http::on(r, "PUT", "/user/following/:user") {
        r197(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "DELETE", "/user/following/:user") {
        r198(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/users/:user/keys") {
        r199(cx, state, rest::param(cx, r, "user"));
    } else if http::on(r, "GET", "/user/keys") {
        r200(cx, state);
    } else if http::on(r, "GET", "/user/keys/:id") {
        r201(cx, state, rest::param(cx, r, "id"));
    } else if http::on(r, "POST", "/user/keys") {
        r202(cx, state);
    } else if http::on(r, "DELETE", "/user/keys/:id") {
        r203(cx, state, rest::param(cx, r, "id"));
    } else {
        rest::otherwise(cx, r);
    }
}
