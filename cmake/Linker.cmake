macro(nxv_configure_linker project_name)
  set(nxv_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(nxv_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE nxv_USER_LINKER_OPTION PROPERTY STRINGS ${nxv_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    nxv_USER_LINKER_OPTION_VALUES
    ${nxv_USER_LINKER_OPTION}
    nxv_USER_LINKER_OPTION_INDEX)

  if(${nxv_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${nxv_USER_LINKER_OPTION}', explicitly supported entries are ${nxv_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${nxv_USER_LINKER_OPTION}")
endmacro()
