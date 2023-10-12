/*!
 * This source file is part of the Swift.org open source project
 *
 * Copyright (c) 2021 Apple Inc. and the Swift project authors
 * Licensed under Apache License v2.0 with Runtime Library Exception
 *
 * See https://swift.org/LICENSE.txt for license information
 * See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */
"use strict";(self["webpackChunkswift_docc_render"]=self["webpackChunkswift_docc_render"]||[]).push([[37],{7432:function(e,t,n){n.d(t,{Z:function(){return d}});var r=function(){var e=this,t=e._self._c;return t("span",{staticClass:"badge",class:{[`badge-${e.variant}`]:e.variant},attrs:{role:"presentation"}},[e._t("default",(function(){return[e._v(e._s(e.text?e.$t(e.text):""))]}))],2)},a=[];const i={beta:"aside-kind.beta",deprecated:"aside-kind.deprecated"};var o={name:"Badge",props:{variant:{type:String,default:()=>""}},computed:{text:({variant:e})=>i[e]}},s=o,l=n(1001),c=(0,l.Z)(s,r,a,!1,null,"8d6893ae",null),d=c.exports},9595:function(e,t,n){n.d(t,{Z:function(){return d}});var r=function(){var e=this,t=e._self._c;return t("ContentNode",{staticClass:"conditional-constraints",attrs:{content:e.content}})},a=[],i=n(8846),o={name:"ConditionalConstraints",components:{ContentNode:i.Z},props:{constraints:i.Z.props.content,prefix:i.Z.props.content},computed:{content:({constraints:e,prefix:t,space:n})=>t.concat(n).concat(e),space:()=>({type:i.Z.InlineType.text,text:" "})}},s=o,l=n(1001),c=(0,l.Z)(s,r,a,!1,null,"4c6f3ed1",null),d=c.exports},8846:function(e,t,n){n.d(t,{Z:function(){return d}});var r=function(){var e=this,t=e._self._c;return t("BaseContentNode",e._b({},"BaseContentNode",e.$props,!1))},a=[],i=n(8843),o={name:"ContentNode",components:{BaseContentNode:i["default"]},props:i["default"].props,methods:i["default"].methods,BlockType:i["default"].BlockType,InlineType:i["default"].InlineType},s=o,l=n(1001),c=(0,l.Z)(s,r,a,!1,null,"3a32ffd0",null),d=c.exports},7120:function(e,t,n){n.d(t,{Z:function(){return c}});var r=function(e,t){return e("p",{staticClass:"requirement-metadata",class:t.data.staticClass},[e("strong",[t._v(t._s(t.parent.$t("required")))]),t.props.defaultImplementationsCount?[t._v(" "+t._s(t.parent.$tc("metadata.default-implementation",t.props.defaultImplementationsCount))+" ")]:t._e()],2)},a=[],i={name:"RequirementMetadata",props:{defaultImplementationsCount:{type:Number,default:0}}},o=i,s=n(1001),l=(0,s.Z)(o,r,a,!0,null,null,null),c=l.exports},6213:function(e,t,n){n.d(t,{default:function(){return z}});var r,a,i,o,s,l,c,d,p=n(352),u={name:"ChangedToken",render(e){const{kind:t,tokens:n}=this;return e("span",{class:[`token-${t}`,"token-changed"]},n.map((t=>e(z,{props:t}))))},props:{kind:{type:String,required:!0},tokens:{type:Array,required:!0}}},f=u,m=n(1001),h=(0,m.Z)(f,r,a,!1,null,null,null),g=h.exports,y=n(245),v=n(5953),k={name:"LinkableToken",mixins:[v.Z],render(e){const t=this.references[this.identifier];return t&&t.url?e(y.Z,{props:{url:t.url,kind:t.kind,role:t.role}},this.$slots.default):e("span",{},this.$slots.default)},props:{identifier:{type:String,required:!0,default:()=>""}}},b=k,C=(0,m.Z)(b,i,o,!1,null,null,null),_=C.exports,x={name:"RawText",render(e){const{_v:t=(t=>e("span",t)),text:n}=this;return t(n)},props:{text:{type:String,required:!0}}},Z=x,B=(0,m.Z)(Z,s,l,!1,null,null,null),T=B.exports,S={name:"SyntaxToken",render(e){return e("span",{class:`token-${this.kind}`},this.text)},props:{kind:{type:String,required:!0},text:{type:String,required:!0}}},I=S,O=(0,m.Z)(I,c,d,!1,null,null,null),$=O.exports;const q={attribute:"attribute",externalParam:"externalParam",genericParameter:"genericParameter",identifier:"identifier",internalParam:"internalParam",keyword:"keyword",label:"label",number:"number",string:"string",text:"text",typeIdentifier:"typeIdentifier",added:"added",removed:"removed"};var w,A,L={name:"DeclarationToken",render(e){const{kind:t,text:n,tokens:r}=this;switch(t){case q.text:{const t={text:n};return e(T,{props:t})}case q.typeIdentifier:{const t={identifier:this.identifier};return e(_,{class:"type-identifier-link",props:t},[e(p.Z,n)])}case q.attribute:{const{identifier:r}=this;return r?e(_,{class:"attribute-link",props:{identifier:r}},[e(p.Z,n)]):e($,{props:{kind:t,text:n}})}case q.added:case q.removed:return e(g,{props:{tokens:r,kind:t}});default:{const r={kind:t,text:n};return e($,{props:r})}}},constants:{TokenKind:q},props:{kind:{type:String,required:!0},identifier:{type:String,required:!1},text:{type:String,required:!1},tokens:{type:Array,required:!1,default:()=>[]}}},P=L,F=(0,m.Z)(P,w,A,!1,null,"3fd63d6c",null),z=F.exports},9037:function(e,t,n){n.r(t),n.d(t,{default:function(){return ne}});var r=function(){var e=this,t=e._self._c;return t("div",{staticClass:"link-block",class:e.linkBlockClasses},[t(e.linkComponent,e._b({ref:"apiChangesDiff",tag:"component",staticClass:"link",class:e.linkClasses},"component",e.linkProps,!1),[e.topic.role&&!e.change?t("TopicLinkBlockIcon",{attrs:{role:e.topic.role,imageOverride:e.references[e.iconOverride]}}):e._e(),e.topic.fragments?t("DecoratedTopicTitle",{attrs:{tokens:e.topic.fragments}}):t("WordBreak",{attrs:{tag:e.titleTag}},[e._v(e._s(e.topic.title))]),e.change?t("span",{staticClass:"visuallyhidden"},[e._v("- "+e._s(e.$t(e.changeName)))]):e._e()],1),e.hasAbstractElements?t("div",{staticClass:"abstract"},[e.topic.abstract?t("ContentNode",{attrs:{content:e.topic.abstract}}):e._e(),e.topic.ideTitle?t("div",{staticClass:"topic-keyinfo"},[e.topic.titleStyle===e.titleStyles.title?[t("strong",[e._v("Key:")]),e._v(" "+e._s(e.topic.name)+" ")]:e.topic.titleStyle===e.titleStyles.symbol?[t("strong",[e._v("Name:")]),e._v(" "+e._s(e.topic.ideTitle)+" ")]:e._e()],2):e._e(),e.topic.required||e.topic.defaultImplementations?t("RequirementMetadata",{staticClass:"topic-required",attrs:{defaultImplementationsCount:e.topic.defaultImplementations}}):e._e(),e.topic.conformance?t("ConditionalConstraints",{attrs:{constraints:e.topic.conformance.constraints,prefix:e.topic.conformance.availabilityPrefix}}):e._e()],1):e._e(),e.showDeprecatedBadge?t("Badge",{attrs:{variant:"deprecated"}}):e.showBetaBadge?t("Badge",{attrs:{variant:"beta"}}):e._e(),e._l(e.tags,(function(n){return t("Badge",{key:`${n.type}-${n.text}`,attrs:{variant:n.type}},[e._v(" "+e._s(n.text)+" ")])}))],2)},a=[],i=n(7192),o=n(2449),s=n(7432),l=n(352),c=n(8846),d=function(){var e=this,t=e._self._c;return e.imageOverride||e.icon?t("div",{staticClass:"topic-icon-wrapper"},[e.imageOverride?t("OverridableAsset",{staticClass:"topic-icon",attrs:{imageOverride:e.imageOverride}}):e.icon?t(e.icon,{tag:"component",staticClass:"topic-icon"}):e._e()],1):e._e()},p=[],u=n(5692),f=n(7775),m=function(){var e=this,t=e._self._c;return t("SVGIcon",{staticClass:"api-reference-icon",attrs:{viewBox:"0 0 14 14",themeId:"api-reference"}},[t("title",[e._v(e._s(e.$t("api-reference")))]),t("path",{attrs:{d:"m1 1v12h12v-12zm11 11h-10v-10h10z"}}),t("path",{attrs:{d:"m3 4h8v1h-8zm0 2.5h8v1h-8zm0 2.5h8v1h-8z"}}),t("path",{attrs:{d:"m3 4h8v1h-8z"}}),t("path",{attrs:{d:"m3 6.5h8v1h-8z"}}),t("path",{attrs:{d:"m3 9h8v1h-8z"}})])},h=[],g=n(3453),y={name:"APIReferenceIcon",components:{SVGIcon:g.Z}},v=y,k=n(1001),b=(0,k.Z)(v,m,h,!1,null,null,null),C=b.exports,_=function(){var e=this,t=e._self._c;return t("SVGIcon",{attrs:{viewBox:"0 0 14 14",themeId:"endpoint"}},[t("title",[e._v(e._s(e.$t("icons.web-service-endpoint")))]),t("path",{attrs:{d:"M4.052 8.737h-1.242l-1.878 5.263h1.15l0.364-1.081h1.939l0.339 1.081h1.193zM2.746 12.012l0.678-2.071 0.653 2.071z"}}),t("path",{attrs:{d:"M11.969 8.737h1.093v5.263h-1.093v-5.263z"}}),t("path",{attrs:{d:"M9.198 8.737h-2.295v5.263h1.095v-1.892h1.12c0.040 0.003 0.087 0.004 0.134 0.004 0.455 0 0.875-0.146 1.217-0.394l-0.006 0.004c0.296-0.293 0.48-0.699 0.48-1.148 0-0.060-0.003-0.118-0.010-0.176l0.001 0.007c0.003-0.039 0.005-0.085 0.005-0.131 0-0.442-0.183-0.842-0.476-1.128l-0-0c-0.317-0.256-0.724-0.41-1.168-0.41-0.034 0-0.069 0.001-0.102 0.003l0.005-0zM9.628 11.014c-0.15 0.118-0.341 0.188-0.548 0.188-0.020 0-0.040-0.001-0.060-0.002l0.003 0h-1.026v-1.549h1.026c0.017-0.001 0.037-0.002 0.058-0.002 0.206 0 0.396 0.066 0.551 0.178l-0.003-0.002c0.135 0.13 0.219 0.313 0.219 0.515 0 0.025-0.001 0.050-0.004 0.074l0-0.003c0.002 0.020 0.003 0.044 0.003 0.068 0 0.208-0.083 0.396-0.219 0.534l0-0z"}}),t("path",{attrs:{d:"M13.529 4.981c0-1.375-1.114-2.489-2.489-2.49h-0l-0.134 0.005c-0.526-1.466-1.903-2.496-3.522-2.496-0.892 0-1.711 0.313-2.353 0.835l0.007-0.005c-0.312-0.243-0.709-0.389-1.14-0.389-1.030 0-1.865 0.834-1.866 1.864v0c0 0.001 0 0.003 0 0.004 0 0.123 0.012 0.242 0.036 0.358l-0.002-0.012c-0.94 0.37-1.593 1.27-1.593 2.323 0 1.372 1.11 2.485 2.482 2.49h8.243c1.306-0.084 2.333-1.164 2.333-2.484 0-0.001 0-0.002 0-0.003v0zM11.139 6.535h-8.319c-0.799-0.072-1.421-0.739-1.421-1.551 0-0.659 0.41-1.223 0.988-1.45l0.011-0.004 0.734-0.28-0.148-0.776-0.012-0.082v-0.088c0-0 0-0.001 0-0.001 0-0.515 0.418-0.933 0.933-0.933 0.216 0 0.416 0.074 0.574 0.197l-0.002-0.002 0.584 0.453 0.575-0.467 0.169-0.127c0.442-0.306 0.991-0.489 1.581-0.489 1.211 0 2.243 0.769 2.633 1.846l0.006 0.019 0.226 0.642 0.814-0.023 0.131 0.006c0.805 0.067 1.432 0.736 1.432 1.552 0 0.836-0.659 1.518-1.486 1.556l-0.003 0z"}})])},x=[],Z={name:"EndpointIcon",components:{SVGIcon:g.Z}},B=Z,T=(0,k.Z)(B,_,x,!1,null,null,null),S=T.exports,I=n(8633),O=n(9001),$=n(8638),q=n(6664);const w={[i.L.article]:u.Z,[i.L.collection]:O.Z,[i.L.collectionGroup]:C,[i.L.learn]:I.Z,[i.L.overview]:I.Z,[i.L.project]:$.Z,[i.L.tutorial]:$.Z,[i.L.resources]:I.Z,[i.L.sampleCode]:f.Z,[i.L.restRequestSymbol]:S};var A={components:{OverridableAsset:q.Z,SVGIcon:g.Z},props:{role:{type:String,required:!0},imageOverride:{type:Object,default:null}},computed:{icon:({role:e})=>w[e]}},L=A,P=(0,k.Z)(L,d,p,!1,null,"44dade98",null),F=P.exports,z=function(){var e=this,t=e._self._c;return t("code",{staticClass:"decorated-title"},e._l(e.tokens,(function(n,r){return t(e.componentFor(n),{key:r,tag:"component",class:[e.classFor(n),e.emptyTokenClass(n)]},[e._v(e._s(n.text))])})),1)},D=[],N=n(6213);const{TokenKind:M}=N["default"].constants,j={decorator:"decorator",identifier:"identifier",label:"label"};var V={name:"DecoratedTopicTitle",components:{WordBreak:l.Z},props:{tokens:{type:Array,required:!0,default:()=>[]}},constants:{TokenKind:M},methods:{emptyTokenClass:({text:e})=>({"empty-token":" "===e}),classFor({kind:e}){switch(e){case M.externalParam:case M.identifier:return j.identifier;case M.label:return j.label;default:return j.decorator}},componentFor(e){return/^\s+$/.test(e.text)?"span":l.Z}}},R=V,G=(0,k.Z)(R,z,D,!1,null,"06ec7395",null),W=G.exports,E=n(9595),H=n(7120),K=n(1842),J=n(5953);const Y={article:"article",symbol:"symbol"},Q={title:"title",symbol:"symbol"},U={link:"link"};var X={name:"TopicsLinkBlock",components:{Badge:s.Z,WordBreak:l.Z,ContentNode:c.Z,TopicLinkBlockIcon:F,DecoratedTopicTitle:W,RequirementMetadata:H.Z,ConditionalConstraints:E.Z},mixins:[K.JY,K.PH,J.Z],constants:{ReferenceType:U,TopicKind:Y,TitleStyles:Q},props:{isSymbolBeta:Boolean,isSymbolDeprecated:Boolean,topic:{type:Object,required:!0,validator:e=>(!("abstract"in e)||Array.isArray(e.abstract))&&"string"===typeof e.identifier&&(e.type===U.link&&!e.kind||"string"===typeof e.kind)&&(e.type===U.link&&!e.role||"string"===typeof e.role)&&"string"===typeof e.title&&"string"===typeof e.url&&(!("defaultImplementations"in e)||"number"===typeof e.defaultImplementations)&&(!("required"in e)||"boolean"===typeof e.required)&&(!("conformance"in e)||"object"===typeof e.conformance)}},data(){return{state:this.store.state}},computed:{linkComponent:({topic:e})=>e.type===U.link?"a":"router-link",linkProps({topic:e}){const t=(0,o.Q2)(e.url,this.$route.query);return e.type===U.link?{href:t}:{to:t}},linkBlockClasses:({changesClasses:e,hasAbstractElements:t,displaysMultipleLinesAfterAPIChanges:n,multipleLinesClass:r})=>({"has-inline-element":!t,[r]:n,...!t&&e}),linkClasses:({changesClasses:e,deprecated:t,hasAbstractElements:n})=>({deprecated:t,"has-adjacent-elements":n,...n&&e}),changesClasses:({getChangesClasses:e,change:t})=>e(t),titleTag({topic:e}){if(e.titleStyle===Q.title)return e.ideTitle?"span":"code";if(e.role&&(e.role===i.L.collection||e.role===i.L.dictionarySymbol))return"span";switch(e.kind){case Y.symbol:return"code";default:return"span"}},titleStyles:()=>Q,deprecated:({showDeprecatedBadge:e,topic:t})=>e||t.deprecated,showBetaBadge:({topic:e,isSymbolBeta:t})=>Boolean(!t&&e.beta),showDeprecatedBadge:({topic:e,isSymbolDeprecated:t})=>Boolean(!t&&e.deprecated),change({topic:{identifier:e},state:{apiChanges:t}}){return this.changeFor(e,t)},changeName:({change:e,getChangeName:t})=>t(e),hasAbstractElements:({topic:{abstract:e,conformance:t,required:n,defaultImplementations:r}}={})=>e&&e.length>0||t||n||r,tags:({topic:e})=>(e.tags||[]).slice(0,1),iconOverride:({topic:{images:e=[]}})=>{const t=e.find((({type:e})=>"icon"===e));return t?t.identifier:null}}},ee=X,te=(0,k.Z)(ee,r,a,!1,null,"63be6b46",null),ne=te.exports},9426:function(e,t,n){n.d(t,{Ag:function(){return i},UG:function(){return a},ct:function(){return o},yf:function(){return r}});const r={added:"added",modified:"modified",deprecated:"deprecated"},a=[r.modified,r.added,r.deprecated],i={[r.modified]:"change-type.modified",[r.added]:"change-type.added",[r.deprecated]:"change-type.deprecated"},o={"change-type.modified":r.modified,"change-type.added":r.added,"change-type.deprecated":r.deprecated}},4733:function(e,t,n){n.d(t,{_:function(){return r}});const r="displays-multiple-lines"},1842:function(e,t,n){n.d(t,{JY:function(){return c},PH:function(){return l}});var r=n(9426),a=n(4733),i=n(3112);const o="latest_",s={xcode:{value:"xcode",label:"Xcode"},other:{value:"other",label:"Other"}},l={constants:{multipleLinesClass:a._},data(){return{multipleLinesClass:a._}},computed:{displaysMultipleLinesAfterAPIChanges:({change:e,changeType:t,$refs:n})=>!(!e&&!t)&&(0,i.s)(n.apiChangesDiff)}},c={methods:{toVersionRange({platform:e,versions:t}){return`${e} ${t[0]} – ${e} ${t[1]}`},toOptionValue:e=>`${o}${e}`,toScope:e=>e.slice(o.length,e.length),getOptionsForDiffAvailability(e={}){return this.getOptionsForDiffAvailabilities([e])},getOptionsForDiffAvailabilities(e=[]){const t=e.reduce(((e,t={})=>Object.keys(t).reduce(((e,n)=>({...e,[n]:(e[n]||[]).concat(t[n])})),e)),{}),n=Object.keys(t),r=n.reduce(((e,n)=>{const r=t[n];return{...e,[n]:r.find((e=>e.platform===s.xcode.label))||r[0]}}),{}),a=e=>({label:this.toVersionRange(r[e]),value:this.toOptionValue(e),platform:r[e].platform}),{sdk:i,beta:o,minor:l,major:c,...d}=r,p=[].concat(i?a("sdk"):[]).concat(o?a("beta"):[]).concat(l?a("minor"):[]).concat(c?a("major"):[]).concat(Object.keys(d).map(a));return this.splitOptionsPerPlatform(p)},changesClassesFor(e,t){const n=this.changeFor(e,t);return this.getChangesClasses(n)},getChangesClasses:e=>({[`changed changed-${e}`]:!!e}),changeFor(e,t){const{change:n}=(t||{})[e]||{};return n},splitOptionsPerPlatform(e){return e.reduce(((e,t)=>{const n=t.platform===s.xcode.label?s.xcode.value:s.other.value;return e[n].push(t),e}),{[s.xcode.value]:[],[s.other.value]:[]})},getChangeName(e){return r.Ag[e]}},computed:{availableOptions({diffAvailability:e={},toOptionValue:t}){return new Set(Object.keys(e).map(t))}}}},3112:function(e,t,n){function r(e){if(!e)return!1;const t=window.getComputedStyle(e.$el||e),n=(e.$el||e).offsetHeight,r=t.lineHeight?parseFloat(t.lineHeight):1,a=t.paddingTop?parseFloat(t.paddingTop):0,i=t.paddingBottom?parseFloat(t.paddingBottom):0,o=t.borderTopWidth?parseFloat(t.borderTopWidth):0,s=t.borderBottomWidth?parseFloat(t.borderBottomWidth):0,l=n-(a+i+o+s),c=l/r;return c>=2}n.d(t,{s:function(){return r}})}}]);