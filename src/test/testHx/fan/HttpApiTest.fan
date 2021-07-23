//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using concurrent
using haystack
using auth
using axon
using hx

**
** HttpApiTest
**
class HttpApiTest : HxTest
{
  Uri? uri

  Client? a  // alice (op)
  Client? b  // bob (admin)
  Client? c  // charlie (su)

  Dict? siteA
  Dict? siteB
  Dict? siteC

  @HxRuntimeTest
  Void test()
  {
    init
    doAuth
    doAbout
    doRead
    doCommit
    doGets
  }

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  private Void init()
  {
    try { rt.libs.add("hxHttp") } catch (Err e) {}
    this.uri = rt.siteUri + rt.apiUri

    // setup user accounts
    addUser("alice",   "a-secret", ["userRole":"op"])
    addUser("bob",     "b-secret", ["userRole":"admin"])
    addUser("charlie", "c-secret", ["userRole":"su"])

    // setup some site records
    siteA = addRec(["dis":"A", "site":m, "geoCity":"Richmond", "area":n(30_000)])
    siteB = addRec(["dis":"B", "site":m, "geoCity":"Norfolk",  "area":n(20_000)])
    siteC = addRec(["dis":"C", "site":m, "geoCity":"Roanoke",  "area":n(10_000)])

  }

//////////////////////////////////////////////////////////////////////////
// Auth
//////////////////////////////////////////////////////////////////////////

  private Void doAuth()
  {
    a = authOk("alice",   "a-secret")
    b = authOk("bob",     "b-secret")
    c = authOk("charlie", "c-secret")

    authFail("wrong", "wrong")
    authFail("alice", "wrong")
  }

  private Client authOk(Str user, Str pass)
  {
    c := auth(user, pass)
    verifyEq(c.auth->user, user)
    return c
  }

  private Void authFail(Str user, Str pass)
  {
    verifyErr(AuthErr#) { auth(user, pass) }
  }

  private Client auth(Str user, Str pass)
  {
    Client.open(uri, user, pass)
  }

//////////////////////////////////////////////////////////////////////////
// About
//////////////////////////////////////////////////////////////////////////

  private Void doAbout()
  {
    verifyAbout(a)
    verifyAbout(b)
    verifyAbout(c)
  }

  private Void verifyAbout(Client c)
  {
    about := c.about
    verifyEq(about->haystackVersion,      rt.ns.lib("ph").version.toStr)
    verifyEq(about->whoami,               c.auth->user)
    verifyEq(about->tz,                   TimeZone.cur.name)
    verifyEq(about->productName,          rt.platform.productName)
    verifyEq(about->productVersion,       rt.platform.productVersion)
    verifyEq(about->vendorName,           rt.platform.vendorName)
    verifyEq(about->vendorUri,            rt.platform.vendorUri)
    verifyEq(about->serverName,           Env.cur.host)
    verifyEq(about->serverTime->date,     Date.today)
    verifyEq(about->serverBootTime->date, Date.today)
  }

//////////////////////////////////////////////////////////////////////////
// Read
//////////////////////////////////////////////////////////////////////////

  private Void doRead()
  {
    verifyAbout(a)
    verifyAbout(b)
    verifyAbout(c)
  }

  private Void verifyRead(Client c)
  {
    // readAll
    g := c.readAll("site")
    verifyDictsEq(g.toRows, [siteA, siteB, siteC], false)
    g = c.readAll("notThere")
    verifyEq(g.size, 0)

    // read ok
    dict := c.read("site")
    verifyEq(["A", "B", "C"].contains(dict.dis), true)

    // read bad
    verifyEq(c.read("notThere", false), null)
    verifyErr(UnknownRecErr#) { c.read("notThere") }

    // readById ok
    dict = c.readById(siteB.id)
    verifyDictEq(dict, siteB)

    // readById bad
    verifyEq(c.readById(Ref.gen, false), null)
    verifyErr(UnknownRecErr#) { c.readById(Ref.gen) }

    // readByIds ok
    g = c.readByIds([siteA.id, siteB.id, siteC.id])
    verifyDictsEq(g.toRows, [siteA, siteB, siteC], true)
    g = c.readByIds([siteC.id, siteB.id, siteA.id])
    verifyDictsEq(g.toRows, [siteC, siteB, siteA], true)

    // readByIds bad
    g = c.readByIds([siteA.id, siteB.id, siteC.id, Ref.gen], false)
    verifyDictsEq(g.toRows[0..2], [siteA, siteB, siteC], true)
    verifyDictEq(g[-1], Etc.emptyDict)
    verifyErr(UnknownRecErr#) { c.readByIds([siteA.id, Ref.gen]) }

    // raw read by filter
    g = c.call("read", Etc.makeMapGrid(null, ["filter":"area >= 20000"]))
    verifyDictsEq(g.toRows, [siteA, siteB], false)

    // raw read by filter with limit
    g = c.call("read", Etc.makeMapGrid(null, ["filter":"site", "limit":n(2)]))
    verifyEq(g.size, 2)

    // raw read by id
    g = c.call("read", Etc.makeListGrid(null, "id", null, [Ref.gen, siteB.id, Ref.gen, siteC.id]))
    verifyDictEq(g[0], Etc.emptyDict)
    verifyDictEq(g[1], siteB)
    verifyDictEq(g[2], Etc.emptyDict)
    verifyDictEq(g[3], siteC)
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  private Void doCommit()
  {
    verifyPermissionErr { this.verifyCommit(this.a) }
    verifyCommit(b)
    verifyCommit(c)
  }

  private Void verifyCommit(Client c)
  {
    // add
    db := rt.db
    verifyEq(db.readCount(Filter("foo")), 0)
    Grid g := c.call("commit", Etc.makeMapGrid(["commit":"add"], ["dis":"Commit Test", "foo":m]))
    r := g.first as Dict
    verifyEq(db.readCount(Filter("foo")), 1)
    verifyDictEq(db.read(Filter("foo")), r)

    // update
    g = c.call("commit", Etc.makeMapGrid(["commit":"update"], ["id":r.id, "mod":r->mod, "bar":"baz"]))
    r = readById(r.id)
    verifyEq(r["bar"], "baz")
    verifyDictEq(r, g.first)

    // update transient
    g = c.call("commit", Etc.makeMapGrid(["commit":"update", "transient":m], ["id":r.id, "mod":r->mod, "curVal":n(123)]))
    r = readById(r.id)
    verifyEq(r["curVal"], n(123))

    // update force
    g = c.call("commit", Etc.makeMapGrid(["commit":"update", "force":m], ["id":r.id, "mod":DateTime.nowUtc, "forceIt":"forced!"]))
    r = readById(r.id)
    verifyEq(r["forceIt"], "forced!")

    // remove
    g = c.call("commit", Etc.makeMapGrid(["commit":"remove"], ["id":r.id, "mod":r->mod]))
    verifyEq(db.readById(r.id, false), null)
  }

//////////////////////////////////////////////////////////////////////////
// Gets
//////////////////////////////////////////////////////////////////////////

  Void doGets()
  {
    // these ops are ok
    verifyEq(callAsGet("about").first->productName, rt.platform.productName)
    verifyEq(callAsGet("defs").size, c.call("defs").size)
    verifyEq(callAsGet("libs").size, c.call("libs").size)
    verifyEq(callAsGet("filetypes").size, c.call("filetypes").size)
    verifyEq(callAsGet("ops").size, c.call("ops").size)
    verifyEq(callAsGet("read?filter=id").size, c.readAll("id").size)

    // these ops are not
    verifyGetNotAllowed("eval?expr=now()")
    verifyGetNotAllowed("commit?id=@foo")
  }

  Grid callAsGet(Str path)
  {
    str := c.toWebClient(path.toUri).getStr
    return ZincReader(str.in).readGrid
  }

  Void verifyGetNotAllowed(Str path)
  {
    wc := c.toWebClient(path.toUri)
    wc.writeReq
    wc.readRes
    verifyEq(wc.resCode, 405)
    verifyEq(wc.resPhrase.startsWith("GET not allowed for op"), true)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Void verifyPermissionErr(|This| f)
  {
    try
    {
      f(this)
      fail
    }
    catch (CallErr e)
    {
      verify(e.msg.startsWith("haystack::PermissionErr:"))
    }
  }

}