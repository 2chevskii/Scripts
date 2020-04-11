#!/usr/bin/env bash
#requires -modules 'PSColorizer'

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param (

    [switch]$UpdateAll,
    [switch]$UpdateServer,
    [switch]$UpdateUmod,


    [Parameter(ParameterSetName = 'Interactive')]
    [switch]$Interactive
)
