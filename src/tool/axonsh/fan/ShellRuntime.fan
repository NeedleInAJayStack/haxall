//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Mar 2023  Brian Frank  Creation
//

using haystack
using folio
using hx

**
** ShellRuntime implements a limited, single-threaded runtime for the shell.
**
internal const class ShellRuntime : HxRuntime, ShellStdServices
{
  new make()
  {
    this.name     = "axonsh"
    this.dir      = Env.cur.workDir + `axonsh/`
    this.version  = typeof.pod.version
    this.platform = HxPlatform(Etc.dict1("axonsh", Marker.val))
    this.config   = HxConfig(Etc.dict0)
    this.db       = ShellFolio(FolioConfig { it.name = this.name; it.dir = this.dir })
  }

  override const Str name

  override const File dir

  override const Version version

  override const HxPlatform platform

  override const HxConfig config

  override const Folio db

  override Namespace ns() { throw UnsupportedErr() }

  override Dict meta() { Etc.dict0 }

  override HxLib? lib(Str name, Bool checked := true) { libs.get(name, checked) }

  override HxRuntimeLibs libs() { throw UnsupportedErr() }

  override Bool isSteadyState() { true }

  override This sync(Duration? timeout := 30sec) { this }

  override Bool isRunning() { true }

  override HxService service(Type type) { services.get(type, true) }

  override const ShellServiceRegistry services := ShellServiceRegistry()
}

**************************************************************************
** ShellStdServices
**************************************************************************

internal const mixin ShellStdServices : HxStdServices
{
  abstract HxService service(Type type)
  override HxContextService context() { service(HxContextService#) }
  override HxObsService obs()         { service(HxObsService#) }
  override HxWatchService watch()     { service(HxWatchService#) }
  override HxFileService file()       { service(HxFileService#)  }
  override HxHisService his()         { service(HxHisService#) }
  override HxCryptoService crypto()   { service(HxCryptoService#) }
  override HxHttpService http()       { service(HxHttpService#) }
  override HxUserService user()       { service(HxUserService#) }
  override HxIOService io()           { service(HxIOService#) }
  override HxTaskService task()       { service(HxTaskService#) }
  override HxConnService conn()       { service(HxConnService#) }
  override HxPointWriteService pointWrite() { service(HxPointWriteService#) }
}

**************************************************************************
** ShellServiceRegistry
**************************************************************************

internal const class ShellServiceRegistry: HxServiceRegistry, ShellStdServices
{
  new make()
  {
    map := Type:HxService[][:]
    map[HxFileService#] = HxService[ShellFileService()]

    this.list = map.keys.sort
    this.map  = map
  }

  override const Type[] list

  override HxService service(Type type) { get(type, true) }

  override HxService? get(Type type, Bool checked := true)
  {
    x := map[type]
    if (x != null) return x.first
    if (checked) throw UnknownServiceErr(type.qname)
    return null
  }

  override HxService[] getAll(Type type)
  {
    map[type] ?: HxService#.emptyList
  }

  private const Type:HxService[] map
}

**************************************************************************
** ShellFileService
**************************************************************************

internal const class ShellFileService : HxFileService
{
  override File resolve(Uri uri) { File(uri, false) }
}

