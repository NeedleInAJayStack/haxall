//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using inet
using web
using wisp
using haystack
using hx

**
** HTTP service handling
**
const class HxHttpLib : HxLib, HxHttpService
{
  WispService wisp() { wispRef.val }
  private const AtomicRef wispRef := AtomicRef(null)

  override Uri siteUri() { `http://localhost:8080/` } // TODO

  override Uri apiUri() { `/api/` }

  override Void onReady()
  {
    port := (rec["httpPort"] as Number ?: Number(8080)).toInt
    addr := (rec["httpAddr"] as Str)?.trimToNull

    wisp := WispService
    {
      it.httpPort = port
      it.addr = addr == null ? null : IpAddr(addr)
      it.root = HxHttpRootMod(this)
      it.errMod = HxHttpErrMod(this)
    }
    wispRef.val = wisp
    wisp.start
  }

  override Void onUnready()
  {
    wisp.stop
  }
}

**************************************************************************
** HxHttpRootMod
**************************************************************************

internal const class HxHttpRootMod : WebMod
{
  new make(HxHttpLib lib) { this.rt = lib.rt; this.lib = lib }

  const HxRuntime rt
  const HxHttpLib lib

  override Void onService()
  {
    req := this.req
    res := this.res
    // echo("-- $req.method $req.uri")

    // use first level of my path to lookup lib
    libName := req.modRel.path.first ?: ""

    // if name is empty, redirect
    if (libName.isEmpty)
    {
      // redirect to shell as the built-in UI
      return res.redirect(`/shell`)
    }

    // lookup lib as hxFoo and foo
    lib := rt.lib("hx"+libName.capitalize, false)
    if (lib == null) lib = rt.lib(libName, false)
    if (lib == null) return res.sendErr(404)

    // check if it supports HxLibWeb
    libWeb := lib.web
    if (libWeb.isUnsupported) return res.sendErr(404)

    // dispatch to lib's HxLibWeb instance
    req.mod = libWeb
    req.modBase = req.modBase + `$libName/`
    libWeb.onService
  }
}

**************************************************************************
** HxHttpErrMod
**************************************************************************

internal const class HxHttpErrMod : WebMod
{
  new make(HxHttpLib lib) { this.lib = lib }

  const HxHttpLib lib

  override Void onService()
  {
    err := (Err)req.stash["err"]
    errTrace := lib.rec.has("disableErrTrace") ? err.toStr : err.traceToStr

    res.headers["Content-Type"] = "text/html; charset=utf-8"
    res.out.html
     .head
       .title.w("$res.statusCode INTERNAL SERVER ERROR").titleEnd
     .headEnd
     .body
       .h1.w("$res.statusCode INTERNAL SERVER ERROR").h1End
       .pre.esc(errTrace).preEnd
     .bodyEnd
     .htmlEnd
  }
}




