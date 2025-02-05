//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//

using util

**
** AST DataType
**
@Js
internal class AType : ASpec
{
  ** Constructor
  new make(FileLoc loc, ALib lib, Str name)
    : super(loc, lib, name, XetoType())
  {
    this.lib   = lib
    this.qname = lib.qname + "::" + name
  }

  ** Return true
  override Bool isType() { true }

  ** Assembled DataType reference
  override XetoType asm() { super.asm }

  ** Parent library
  ALib lib

  ** Qualified name "foo.bar::Baz"
  override const Str qname
}