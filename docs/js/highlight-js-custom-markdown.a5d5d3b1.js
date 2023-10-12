/*!
 * This source file is part of the Swift.org open source project
 *
 * Copyright (c) 2021 Apple Inc. and the Swift project authors
 * Licensed under Apache License v2.0 with Runtime Library Exception
 *
 * See https://swift.org/LICENSE.txt for license information
 * See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */
"use strict";(self["webpackChunkswift_docc_render"]=self["webpackChunkswift_docc_render"]||[]).push([[8642,606],{6525:function(n,e,a){a.r(e),a.d(e,{default:function(){return l}});var i=a(7919);const s={begin:"<doc:",end:">",returnBegin:!0,contains:[{className:"link",begin:"doc:",end:">",excludeEnd:!0}]},t={className:"link",begin:/`{2}(?!`)/,end:/`{2}(?!`)/,excludeBegin:!0,excludeEnd:!0},c={begin:"^>\\s+[Note:|Tip:|Important:|Experiment:|Warning:]",end:"$",returnBegin:!0,contains:[{className:"quote",begin:"^>",end:"\\s+"},{className:"type",begin:"Note|Tip|Important|Experiment|Warning",end:":"},{className:"quote",begin:".*",end:"$",endsParent:!0}]},d={begin:"@",end:"[{\\)\\s]",returnBegin:!0,contains:[{className:"title",begin:"@",end:"[\\s+(]",excludeEnd:!0},{begin:":",end:"[,\\)\n\t]",excludeBegin:!0,keywords:{literal:"true false null undefined"},contains:[{className:"number",begin:"\\b([\\d_]+(\\.[\\deE_]+)?|0x[a-fA-F0-9_]+(\\.[a-fA-F0-9p_]+)?|0b[01_]+|0o[0-7_]+)\\b",endsWithParent:!0,excludeEnd:!0},{className:"string",variants:[{begin:/"""/,end:/"""/},{begin:/"/,end:/"/}],endsParent:!0},{className:"link",begin:"http|https",endsWithParent:!0,excludeEnd:!0}]}]};function l(n){const e=(0,i["default"])(n),a=e.contains.find((({className:n})=>"code"===n));a.variants=a.variants.filter((({begin:n})=>!n.includes("( {4}|\\t)")));const l=[...e.contains.filter((({className:n})=>"code"!==n)),a];return{...e,contains:[t,s,c,d,...l]}}},7919:function(n,e,a){function i(n){const e=n.regex,a={begin:/<\/?[A-Za-z_]/,end:">",subLanguage:"xml",relevance:0},i={begin:"^[-\\*]{3,}",end:"$"},s={className:"code",variants:[{begin:"(`{3,})[^`](.|\\n)*?\\1`*[ ]*"},{begin:"(~{3,})[^~](.|\\n)*?\\1~*[ ]*"},{begin:"```",end:"```+[ ]*$"},{begin:"~~~",end:"~~~+[ ]*$"},{begin:"`.+?`"},{begin:"(?=^( {4}|\\t))",contains:[{begin:"^( {4}|\\t)",end:"(\\n)$"}],relevance:0}]},t={className:"bullet",begin:"^[ \t]*([*+-]|(\\d+\\.))(?=\\s+)",end:"\\s+",excludeEnd:!0},c={begin:/^\[[^\n]+\]:/,returnBegin:!0,contains:[{className:"symbol",begin:/\[/,end:/\]/,excludeBegin:!0,excludeEnd:!0},{className:"link",begin:/:\s*/,end:/$/,excludeBegin:!0}]},d=/[A-Za-z][A-Za-z0-9+.-]*/,l={variants:[{begin:/\[.+?\]\[.*?\]/,relevance:0},{begin:/\[.+?\]\(((data|javascript|mailto):|(?:http|ftp)s?:\/\/).*?\)/,relevance:2},{begin:e.concat(/\[.+?\]\(/,d,/:\/\/.*?\)/),relevance:2},{begin:/\[.+?\]\([./?&#].*?\)/,relevance:1},{begin:/\[.*?\]\(.*?\)/,relevance:0}],returnBegin:!0,contains:[{match:/\[(?=\])/},{className:"string",relevance:0,begin:"\\[",end:"\\]",excludeBegin:!0,returnEnd:!0},{className:"link",relevance:0,begin:"\\]\\(",end:"\\)",excludeBegin:!0,excludeEnd:!0},{className:"symbol",relevance:0,begin:"\\]\\[",end:"\\]",excludeBegin:!0,excludeEnd:!0}]},r={className:"strong",contains:[],variants:[{begin:/_{2}/,end:/_{2}/},{begin:/\*{2}/,end:/\*{2}/}]},g={className:"emphasis",contains:[],variants:[{begin:/\*(?!\*)/,end:/\*/},{begin:/_(?!_)/,end:/_/,relevance:0}]};r.contains.push(g),g.contains.push(r);let o=[a,l];r.contains=r.contains.concat(o),g.contains=g.contains.concat(o),o=o.concat(r,g);const b={className:"section",variants:[{begin:"^#{1,6}",end:"$",contains:o},{begin:"(?=^.+?\\n[=-]{2,}$)",contains:[{begin:"^[=-]*$"},{begin:"^",end:"\\n",contains:o}]}]},u={className:"quote",begin:"^>\\s+",contains:o,end:"$"};return{name:"Markdown",aliases:["md","mkdown","mkd"],contains:[b,a,t,r,g,u,s,i,l,c]}}a.r(e),a.d(e,{default:function(){return i}})}}]);