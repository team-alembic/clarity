import{a as Qt}from"./chunk-U3DAOEKE.js";import{b as Xt,c as Jt}from"./chunk-7FBNILPU.js";import{a as Zt}from"./chunk-HOVQUFKF.js";import"./chunk-25KVF5ZE.js";import"./chunk-SYLKYOD7.js";import"./chunk-RQ4TNDAP.js";import"./chunk-GBZODHCW.js";import{h as qt}from"./chunk-M3HLRMUQ.js";import"./chunk-MJH7FT7R.js";import"./chunk-YORIST7Z.js";import"./chunk-TLW7XDGS.js";import"./chunk-DX65XZG2.js";import"./chunk-E2L3Z2Q7.js";import{b as Ut,c as Ht,d as zt,e as Kt}from"./chunk-HIGPS4L2.js";import{g as Wt,q as jt}from"./chunk-Y644KXBG.js";import"./chunk-XOFC523S.js";import{$,O as M,U as Ft,V as Pt,W as Bt,X as Gt,Y as Yt,Z as Vt,_ as Mt,g as $t}from"./chunk-7DACH2LC.js";import{b as E,h as gt}from"./chunk-6DUNJTNJ.js";import{a as p}from"./chunk-EIBFAW37.js";import"./chunk-ETOMFKZJ.js";var xt=(function(){var t=p(function(V,o,f,n){for(f=f||{},n=V.length;n--;f[V[n]]=o);return f},"o"),e=[1,2],s=[1,3],a=[1,4],i=[2,4],h=[1,9],d=[1,11],u=[1,16],c=[1,17],m=[1,18],y=[1,19],T=[1,33],L=[1,20],O=[1,21],D=[1,22],S=[1,23],w=[1,24],C=[1,26],F=[1,27],I=[1,28],P=[1,29],v=[1,30],z=[1,31],at=[1,32],nt=[1,35],ot=[1,36],lt=[1,37],ct=[1,38],K=[1,34],g=[1,4,5,16,17,19,21,22,24,25,26,27,28,29,33,35,37,38,41,45,48,51,52,53,54,57],ht=[1,4,5,14,15,16,17,19,21,22,24,25,26,27,28,29,33,35,37,38,39,40,41,45,48,51,52,53,54,57],Nt=[4,5,16,17,19,21,22,24,25,26,27,28,29,33,35,37,38,41,45,48,51,52,53,54,57],kt={trace:p(function(){},"trace"),yy:{},symbols_:{error:2,start:3,SPACE:4,NL:5,SD:6,document:7,line:8,statement:9,classDefStatement:10,styleStatement:11,cssClassStatement:12,idStatement:13,DESCR:14,"-->":15,HIDE_EMPTY:16,scale:17,WIDTH:18,COMPOSIT_STATE:19,STRUCT_START:20,STRUCT_STOP:21,STATE_DESCR:22,AS:23,ID:24,FORK:25,JOIN:26,CHOICE:27,CONCURRENT:28,note:29,notePosition:30,NOTE_TEXT:31,direction:32,acc_title:33,acc_title_value:34,acc_descr:35,acc_descr_value:36,acc_descr_multiline_value:37,CLICK:38,STRING:39,HREF:40,classDef:41,CLASSDEF_ID:42,CLASSDEF_STYLEOPTS:43,DEFAULT:44,style:45,STYLE_IDS:46,STYLEDEF_STYLEOPTS:47,class:48,CLASSENTITY_IDS:49,STYLECLASS:50,direction_tb:51,direction_bt:52,direction_rl:53,direction_lr:54,eol:55,";":56,EDGE_STATE:57,STYLE_SEPARATOR:58,left_of:59,right_of:60,$accept:0,$end:1},terminals_:{2:"error",4:"SPACE",5:"NL",6:"SD",14:"DESCR",15:"-->",16:"HIDE_EMPTY",17:"scale",18:"WIDTH",19:"COMPOSIT_STATE",20:"STRUCT_START",21:"STRUCT_STOP",22:"STATE_DESCR",23:"AS",24:"ID",25:"FORK",26:"JOIN",27:"CHOICE",28:"CONCURRENT",29:"note",31:"NOTE_TEXT",33:"acc_title",34:"acc_title_value",35:"acc_descr",36:"acc_descr_value",37:"acc_descr_multiline_value",38:"CLICK",39:"STRING",40:"HREF",41:"classDef",42:"CLASSDEF_ID",43:"CLASSDEF_STYLEOPTS",44:"DEFAULT",45:"style",46:"STYLE_IDS",47:"STYLEDEF_STYLEOPTS",48:"class",49:"CLASSENTITY_IDS",50:"STYLECLASS",51:"direction_tb",52:"direction_bt",53:"direction_rl",54:"direction_lr",56:";",57:"EDGE_STATE",58:"STYLE_SEPARATOR",59:"left_of",60:"right_of"},productions_:[0,[3,2],[3,2],[3,2],[7,0],[7,2],[8,2],[8,1],[8,1],[9,1],[9,1],[9,1],[9,1],[9,2],[9,3],[9,4],[9,1],[9,2],[9,1],[9,4],[9,3],[9,6],[9,1],[9,1],[9,1],[9,1],[9,4],[9,4],[9,1],[9,2],[9,2],[9,1],[9,5],[9,5],[10,3],[10,3],[11,3],[12,3],[32,1],[32,1],[32,1],[32,1],[55,1],[55,1],[13,1],[13,1],[13,3],[13,3],[30,1],[30,1]],performAction:p(function(o,f,n,b,k,r,X){var l=r.length-1;switch(k){case 3:return b.setRootDoc(r[l]),r[l];break;case 4:this.$=[];break;case 5:r[l]!="nl"&&(r[l-1].push(r[l]),this.$=r[l-1]);break;case 6:case 7:this.$=r[l];break;case 8:this.$="nl";break;case 12:this.$=r[l];break;case 13:let ut=r[l-1];ut.description=b.trimColon(r[l]),this.$=ut;break;case 14:this.$={stmt:"relation",state1:r[l-2],state2:r[l]};break;case 15:let ft=b.trimColon(r[l]);this.$={stmt:"relation",state1:r[l-3],state2:r[l-1],description:ft};break;case 19:this.$={stmt:"state",id:r[l-3],type:"default",description:"",doc:r[l-1]};break;case 20:var B=r[l],G=r[l-2].trim();if(r[l].match(":")){var Z=r[l].split(":");B=Z[0],G=[G,Z[1]]}this.$={stmt:"state",id:B,type:"default",description:G};break;case 21:this.$={stmt:"state",id:r[l-3],type:"default",description:r[l-5],doc:r[l-1]};break;case 22:this.$={stmt:"state",id:r[l],type:"fork"};break;case 23:this.$={stmt:"state",id:r[l],type:"join"};break;case 24:this.$={stmt:"state",id:r[l],type:"choice"};break;case 25:this.$={stmt:"state",id:b.getDividerId(),type:"divider"};break;case 26:this.$={stmt:"state",id:r[l-1].trim(),note:{position:r[l-2].trim(),text:r[l].trim()}};break;case 29:this.$=r[l].trim(),b.setAccTitle(this.$);break;case 30:case 31:this.$=r[l].trim(),b.setAccDescription(this.$);break;case 32:this.$={stmt:"click",id:r[l-3],url:r[l-2],tooltip:r[l-1]};break;case 33:this.$={stmt:"click",id:r[l-3],url:r[l-1],tooltip:""};break;case 34:case 35:this.$={stmt:"classDef",id:r[l-1].trim(),classes:r[l].trim()};break;case 36:this.$={stmt:"style",id:r[l-1].trim(),styleClass:r[l].trim()};break;case 37:this.$={stmt:"applyClass",id:r[l-1].trim(),styleClass:r[l].trim()};break;case 38:b.setDirection("TB"),this.$={stmt:"dir",value:"TB"};break;case 39:b.setDirection("BT"),this.$={stmt:"dir",value:"BT"};break;case 40:b.setDirection("RL"),this.$={stmt:"dir",value:"RL"};break;case 41:b.setDirection("LR"),this.$={stmt:"dir",value:"LR"};break;case 44:case 45:this.$={stmt:"state",id:r[l].trim(),type:"default",description:""};break;case 46:this.$={stmt:"state",id:r[l-2].trim(),classes:[r[l].trim()],type:"default",description:""};break;case 47:this.$={stmt:"state",id:r[l-2].trim(),classes:[r[l].trim()],type:"default",description:""};break}},"anonymous"),table:[{3:1,4:e,5:s,6:a},{1:[3]},{3:5,4:e,5:s,6:a},{3:6,4:e,5:s,6:a},t([1,4,5,16,17,19,22,24,25,26,27,28,29,33,35,37,38,41,45,48,51,52,53,54,57],i,{7:7}),{1:[2,1]},{1:[2,2]},{1:[2,3],4:h,5:d,8:8,9:10,10:12,11:13,12:14,13:15,16:u,17:c,19:m,22:y,24:T,25:L,26:O,27:D,28:S,29:w,32:25,33:C,35:F,37:I,38:P,41:v,45:z,48:at,51:nt,52:ot,53:lt,54:ct,57:K},t(g,[2,5]),{9:39,10:12,11:13,12:14,13:15,16:u,17:c,19:m,22:y,24:T,25:L,26:O,27:D,28:S,29:w,32:25,33:C,35:F,37:I,38:P,41:v,45:z,48:at,51:nt,52:ot,53:lt,54:ct,57:K},t(g,[2,7]),t(g,[2,8]),t(g,[2,9]),t(g,[2,10]),t(g,[2,11]),t(g,[2,12],{14:[1,40],15:[1,41]}),t(g,[2,16]),{18:[1,42]},t(g,[2,18],{20:[1,43]}),{23:[1,44]},t(g,[2,22]),t(g,[2,23]),t(g,[2,24]),t(g,[2,25]),{30:45,31:[1,46],59:[1,47],60:[1,48]},t(g,[2,28]),{34:[1,49]},{36:[1,50]},t(g,[2,31]),{13:51,24:T,57:K},{42:[1,52],44:[1,53]},{46:[1,54]},{49:[1,55]},t(ht,[2,44],{58:[1,56]}),t(ht,[2,45],{58:[1,57]}),t(g,[2,38]),t(g,[2,39]),t(g,[2,40]),t(g,[2,41]),t(g,[2,6]),t(g,[2,13]),{13:58,24:T,57:K},t(g,[2,17]),t(Nt,i,{7:59}),{24:[1,60]},{24:[1,61]},{23:[1,62]},{24:[2,48]},{24:[2,49]},t(g,[2,29]),t(g,[2,30]),{39:[1,63],40:[1,64]},{43:[1,65]},{43:[1,66]},{47:[1,67]},{50:[1,68]},{24:[1,69]},{24:[1,70]},t(g,[2,14],{14:[1,71]}),{4:h,5:d,8:8,9:10,10:12,11:13,12:14,13:15,16:u,17:c,19:m,21:[1,72],22:y,24:T,25:L,26:O,27:D,28:S,29:w,32:25,33:C,35:F,37:I,38:P,41:v,45:z,48:at,51:nt,52:ot,53:lt,54:ct,57:K},t(g,[2,20],{20:[1,73]}),{31:[1,74]},{24:[1,75]},{39:[1,76]},{39:[1,77]},t(g,[2,34]),t(g,[2,35]),t(g,[2,36]),t(g,[2,37]),t(ht,[2,46]),t(ht,[2,47]),t(g,[2,15]),t(g,[2,19]),t(Nt,i,{7:78}),t(g,[2,26]),t(g,[2,27]),{5:[1,79]},{5:[1,80]},{4:h,5:d,8:8,9:10,10:12,11:13,12:14,13:15,16:u,17:c,19:m,21:[1,81],22:y,24:T,25:L,26:O,27:D,28:S,29:w,32:25,33:C,35:F,37:I,38:P,41:v,45:z,48:at,51:nt,52:ot,53:lt,54:ct,57:K},t(g,[2,32]),t(g,[2,33]),t(g,[2,21])],defaultActions:{5:[2,1],6:[2,2],47:[2,48],48:[2,49]},parseError:p(function(o,f){if(f.recoverable)this.trace(o);else{var n=new Error(o);throw n.hash=f,n}},"parseError"),parse:p(function(o){var f=this,n=[0],b=[],k=[null],r=[],X=this.table,l="",B=0,G=0,Z=0,ut=2,ft=1,Te=r.slice.call(arguments,1),_=Object.create(this.lexer),j={yy:{}};for(var Tt in this.yy)Object.prototype.hasOwnProperty.call(this.yy,Tt)&&(j.yy[Tt]=this.yy[Tt]);_.setInput(o,j.yy),j.yy.lexer=_,j.yy.parser=this,typeof _.yylloc>"u"&&(_.yylloc={});var Et=_.yylloc;r.push(Et);var Ee=_.options&&_.options.ranges;typeof j.yy.parseError=="function"?this.parseError=j.yy.parseError:this.parseError=Object.getPrototypeOf(this).parseError;function _e(N){n.length=n.length-2*N,k.length=k.length-N,r.length=r.length-N}p(_e,"popStack");function Ot(){var N;return N=b.pop()||_.lex()||ft,typeof N!="number"&&(N instanceof Array&&(b=N,N=b.pop()),N=f.symbols_[N]||N),N}p(Ot,"lex");for(var A,_t,U,R,es,vt,J={},pt,Y,Rt,St;;){if(U=n[n.length-1],this.defaultActions[U]?R=this.defaultActions[U]:((A===null||typeof A>"u")&&(A=Ot()),R=X[U]&&X[U][A]),typeof R>"u"||!R.length||!R[0]){var Dt="";St=[];for(pt in X[U])this.terminals_[pt]&&pt>ut&&St.push("'"+this.terminals_[pt]+"'");_.showPosition?Dt="Parse error on line "+(B+1)+`:
`+_.showPosition()+`
Expecting `+St.join(", ")+", got '"+(this.terminals_[A]||A)+"'":Dt="Parse error on line "+(B+1)+": Unexpected "+(A==ft?"end of input":"'"+(this.terminals_[A]||A)+"'"),this.parseError(Dt,{text:_.match,token:this.terminals_[A]||A,line:_.yylineno,loc:Et,expected:St})}if(R[0]instanceof Array&&R.length>1)throw new Error("Parse Error: multiple actions possible at state: "+U+", token: "+A);switch(R[0]){case 1:n.push(A),k.push(_.yytext),r.push(_.yylloc),n.push(R[1]),A=null,_t?(A=_t,_t=null):(G=_.yyleng,l=_.yytext,B=_.yylineno,Et=_.yylloc,Z>0&&Z--);break;case 2:if(Y=this.productions_[R[1]][1],J.$=k[k.length-Y],J._$={first_line:r[r.length-(Y||1)].first_line,last_line:r[r.length-1].last_line,first_column:r[r.length-(Y||1)].first_column,last_column:r[r.length-1].last_column},Ee&&(J._$.range=[r[r.length-(Y||1)].range[0],r[r.length-1].range[1]]),vt=this.performAction.apply(J,[l,G,B,j.yy,R[1],k,r].concat(Te)),typeof vt<"u")return vt;Y&&(n=n.slice(0,-1*Y*2),k=k.slice(0,-1*Y),r=r.slice(0,-1*Y)),n.push(this.productions_[R[1]][0]),k.push(J.$),r.push(J._$),Rt=X[n[n.length-2]][n[n.length-1]],n.push(Rt);break;case 3:return!0}}return!0},"parse")},ke=(function(){var V={EOF:1,parseError:p(function(f,n){if(this.yy.parser)this.yy.parser.parseError(f,n);else throw new Error(f)},"parseError"),setInput:p(function(o,f){return this.yy=f||this.yy||{},this._input=o,this._more=this._backtrack=this.done=!1,this.yylineno=this.yyleng=0,this.yytext=this.matched=this.match="",this.conditionStack=["INITIAL"],this.yylloc={first_line:1,first_column:0,last_line:1,last_column:0},this.options.ranges&&(this.yylloc.range=[0,0]),this.offset=0,this},"setInput"),input:p(function(){var o=this._input[0];this.yytext+=o,this.yyleng++,this.offset++,this.match+=o,this.matched+=o;var f=o.match(/(?:\r\n?|\n).*/g);return f?(this.yylineno++,this.yylloc.last_line++):this.yylloc.last_column++,this.options.ranges&&this.yylloc.range[1]++,this._input=this._input.slice(1),o},"input"),unput:p(function(o){var f=o.length,n=o.split(/(?:\r\n?|\n)/g);this._input=o+this._input,this.yytext=this.yytext.substr(0,this.yytext.length-f),this.offset-=f;var b=this.match.split(/(?:\r\n?|\n)/g);this.match=this.match.substr(0,this.match.length-1),this.matched=this.matched.substr(0,this.matched.length-1),n.length-1&&(this.yylineno-=n.length-1);var k=this.yylloc.range;return this.yylloc={first_line:this.yylloc.first_line,last_line:this.yylineno+1,first_column:this.yylloc.first_column,last_column:n?(n.length===b.length?this.yylloc.first_column:0)+b[b.length-n.length].length-n[0].length:this.yylloc.first_column-f},this.options.ranges&&(this.yylloc.range=[k[0],k[0]+this.yyleng-f]),this.yyleng=this.yytext.length,this},"unput"),more:p(function(){return this._more=!0,this},"more"),reject:p(function(){if(this.options.backtrack_lexer)this._backtrack=!0;else return this.parseError("Lexical error on line "+(this.yylineno+1)+`. You can only invoke reject() in the lexer when the lexer is of the backtracking persuasion (options.backtrack_lexer = true).
`+this.showPosition(),{text:"",token:null,line:this.yylineno});return this},"reject"),less:p(function(o){this.unput(this.match.slice(o))},"less"),pastInput:p(function(){var o=this.matched.substr(0,this.matched.length-this.match.length);return(o.length>20?"...":"")+o.substr(-20).replace(/\n/g,"")},"pastInput"),upcomingInput:p(function(){var o=this.match;return o.length<20&&(o+=this._input.substr(0,20-o.length)),(o.substr(0,20)+(o.length>20?"...":"")).replace(/\n/g,"")},"upcomingInput"),showPosition:p(function(){var o=this.pastInput(),f=new Array(o.length+1).join("-");return o+this.upcomingInput()+`
`+f+"^"},"showPosition"),test_match:p(function(o,f){var n,b,k;if(this.options.backtrack_lexer&&(k={yylineno:this.yylineno,yylloc:{first_line:this.yylloc.first_line,last_line:this.last_line,first_column:this.yylloc.first_column,last_column:this.yylloc.last_column},yytext:this.yytext,match:this.match,matches:this.matches,matched:this.matched,yyleng:this.yyleng,offset:this.offset,_more:this._more,_input:this._input,yy:this.yy,conditionStack:this.conditionStack.slice(0),done:this.done},this.options.ranges&&(k.yylloc.range=this.yylloc.range.slice(0))),b=o[0].match(/(?:\r\n?|\n).*/g),b&&(this.yylineno+=b.length),this.yylloc={first_line:this.yylloc.last_line,last_line:this.yylineno+1,first_column:this.yylloc.last_column,last_column:b?b[b.length-1].length-b[b.length-1].match(/\r?\n?/)[0].length:this.yylloc.last_column+o[0].length},this.yytext+=o[0],this.match+=o[0],this.matches=o,this.yyleng=this.yytext.length,this.options.ranges&&(this.yylloc.range=[this.offset,this.offset+=this.yyleng]),this._more=!1,this._backtrack=!1,this._input=this._input.slice(o[0].length),this.matched+=o[0],n=this.performAction.call(this,this.yy,this,f,this.conditionStack[this.conditionStack.length-1]),this.done&&this._input&&(this.done=!1),n)return n;if(this._backtrack){for(var r in k)this[r]=k[r];return!1}return!1},"test_match"),next:p(function(){if(this.done)return this.EOF;this._input||(this.done=!0);var o,f,n,b;this._more||(this.yytext="",this.match="");for(var k=this._currentRules(),r=0;r<k.length;r++)if(n=this._input.match(this.rules[k[r]]),n&&(!f||n[0].length>f[0].length)){if(f=n,b=r,this.options.backtrack_lexer){if(o=this.test_match(n,k[r]),o!==!1)return o;if(this._backtrack){f=!1;continue}else return!1}else if(!this.options.flex)break}return f?(o=this.test_match(f,k[b]),o!==!1?o:!1):this._input===""?this.EOF:this.parseError("Lexical error on line "+(this.yylineno+1)+`. Unrecognized text.
`+this.showPosition(),{text:"",token:null,line:this.yylineno})},"next"),lex:p(function(){var f=this.next();return f||this.lex()},"lex"),begin:p(function(f){this.conditionStack.push(f)},"begin"),popState:p(function(){var f=this.conditionStack.length-1;return f>0?this.conditionStack.pop():this.conditionStack[0]},"popState"),_currentRules:p(function(){return this.conditionStack.length&&this.conditionStack[this.conditionStack.length-1]?this.conditions[this.conditionStack[this.conditionStack.length-1]].rules:this.conditions.INITIAL.rules},"_currentRules"),topState:p(function(f){return f=this.conditionStack.length-1-Math.abs(f||0),f>=0?this.conditionStack[f]:"INITIAL"},"topState"),pushState:p(function(f){this.begin(f)},"pushState"),stateStackSize:p(function(){return this.conditionStack.length},"stateStackSize"),options:{"case-insensitive":!0},performAction:p(function(f,n,b,k){function r(){let l=n.yytext.indexOf("%%");if(l===0)return!1;if(l>0){let B=n.yytext.slice(0,l),G=n.yytext.slice(l);G&&f.lexer.unput(G),n.yytext=B}return!0}p(r,"processId");var X=k;switch(b){case 0:return 38;case 1:return 40;case 2:return 39;case 3:return 44;case 4:return 51;case 5:return 52;case 6:return 53;case 7:return 54;case 8:return 5;case 9:break;case 10:break;case 11:break;case 12:break;case 13:return this.pushState("SCALE"),17;break;case 14:return 18;case 15:this.popState();break;case 16:return this.begin("acc_title"),33;break;case 17:return this.popState(),"acc_title_value";break;case 18:return this.begin("acc_descr"),35;break;case 19:return this.popState(),"acc_descr_value";break;case 20:this.begin("acc_descr_multiline");break;case 21:this.popState();break;case 22:return"acc_descr_multiline_value";case 23:return this.pushState("CLASSDEF"),41;break;case 24:return this.popState(),this.pushState("CLASSDEFID"),"DEFAULT_CLASSDEF_ID";break;case 25:return this.popState(),this.pushState("CLASSDEFID"),42;break;case 26:return this.popState(),43;break;case 27:return this.pushState("CLASS"),48;break;case 28:return this.popState(),this.pushState("CLASS_STYLE"),49;break;case 29:return this.popState(),50;break;case 30:return this.pushState("STYLE"),45;break;case 31:return this.popState(),this.pushState("STYLEDEF_STYLES"),46;break;case 32:return this.popState(),47;break;case 33:return this.pushState("SCALE"),17;break;case 34:return 18;case 35:this.popState();break;case 36:this.pushState("STATE");break;case 37:return this.popState(),n.yytext=n.yytext.slice(0,-8).trim(),25;break;case 38:return this.popState(),n.yytext=n.yytext.slice(0,-8).trim(),26;break;case 39:return this.popState(),n.yytext=n.yytext.slice(0,-10).trim(),27;break;case 40:return this.popState(),n.yytext=n.yytext.slice(0,-8).trim(),25;break;case 41:return this.popState(),n.yytext=n.yytext.slice(0,-8).trim(),26;break;case 42:return this.popState(),n.yytext=n.yytext.slice(0,-10).trim(),27;break;case 43:return 51;case 44:return 52;case 45:return 53;case 46:return 54;case 47:this.pushState("STATE_STRING");break;case 48:return this.pushState("STATE_ID"),"AS";break;case 49:if(!r())return;return this.popState(),"ID";break;case 50:this.popState();break;case 51:return"STATE_DESCR";case 52:throw new Error('Error: State name must be a single word. Found: "'+n.yytext.trim()+'"');case 53:return 19;case 54:this.popState();break;case 55:return this.popState(),this.pushState("struct"),20;break;case 56:return this.popState(),21;break;case 57:break;case 58:return this.begin("NOTE"),29;break;case 59:return this.popState(),this.pushState("NOTE_ID"),59;break;case 60:return this.popState(),this.pushState("NOTE_ID"),60;break;case 61:this.popState(),this.pushState("FLOATING_NOTE");break;case 62:return this.popState(),this.pushState("FLOATING_NOTE_ID"),"AS";break;case 63:break;case 64:return"NOTE_TEXT";case 65:if(!r())return;return this.popState(),"ID";break;case 66:if(!r())return;return this.popState(),this.pushState("NOTE_TEXT"),24;break;case 67:return this.popState(),n.yytext=n.yytext.substr(2).trim(),31;break;case 68:return this.popState(),n.yytext=n.yytext.slice(0,-8).trim(),31;break;case 69:return 6;case 70:return 6;case 71:return 16;case 72:return 57;case 73:return r()?24:void 0;case 74:return n.yytext=n.yytext.trim(),14;break;case 75:return 15;case 76:return 28;case 77:return 58;case 78:return 5;case 79:return"INVALID"}},"anonymous"),rules:[/^(?:click\b)/i,/^(?:href\b)/i,/^(?:"[^"]*")/i,/^(?:default\b)/i,/^(?:.*direction\s+TB[^\n]*)/i,/^(?:.*direction\s+BT[^\n]*)/i,/^(?:.*direction\s+RL[^\n]*)/i,/^(?:.*direction\s+LR[^\n]*)/i,/^(?:[\n]+)/i,/^(?:[\s]+)/i,/^(?:((?!\n)\s)+)/i,/^(?:#[^\n]*)/i,/^(?:%%(?!\{)[^\n]*)/i,/^(?:scale\s+)/i,/^(?:\d+)/i,/^(?:\s+width\b)/i,/^(?:accTitle\s*:\s*)/i,/^(?:(?!\n||)*[^\n]*)/i,/^(?:accDescr\s*:\s*)/i,/^(?:(?!\n||)*[^\n]*)/i,/^(?:accDescr\s*\{\s*)/i,/^(?:[\}])/i,/^(?:[^\}]*)/i,/^(?:classDef\s+)/i,/^(?:DEFAULT\s+)/i,/^(?:\w+\s+)/i,/^(?:[^\n]*)/i,/^(?:class\s+)/i,/^(?:(\w+)+((,\s*\w+)*))/i,/^(?:[^\n]*)/i,/^(?:style\s+)/i,/^(?:[\w,]+\s+)/i,/^(?:[^\n]*)/i,/^(?:scale\s+)/i,/^(?:\d+)/i,/^(?:\s+width\b)/i,/^(?:state\s+)/i,/^(?:.*<<fork>>)/i,/^(?:.*<<join>>)/i,/^(?:.*<<choice>>)/i,/^(?:.*\[\[fork\]\])/i,/^(?:.*\[\[join\]\])/i,/^(?:.*\[\[choice\]\])/i,/^(?:.*direction\s+TB[^\n]*)/i,/^(?:.*direction\s+BT[^\n]*)/i,/^(?:.*direction\s+RL[^\n]*)/i,/^(?:.*direction\s+LR[^\n]*)/i,/^(?:["])/i,/^(?:\s*as\s+)/i,/^(?:[^\n\{]*)/i,/^(?:["])/i,/^(?:[^"]*)/i,/^(?:\w+\s+\w+.*?\{)/i,/^(?:[^\n\s\{]+)/i,/^(?:\n)/i,/^(?:\{)/i,/^(?:\})/i,/^(?:[\n])/i,/^(?:note\s+)/i,/^(?:left of\b)/i,/^(?:right of\b)/i,/^(?:")/i,/^(?:\s*as\s*)/i,/^(?:["])/i,/^(?:[^"]*)/i,/^(?:[^\n]*)/i,/^(?:\s*[^:\n\s\-]+)/i,/^(?:\s*:[^:\n;]+)/i,/^(?:[\s\S]*?\n\s*end note\b)/i,/^(?:stateDiagram\s+)/i,/^(?:stateDiagram-v2\s+)/i,/^(?:hide empty description\b)/i,/^(?:\[\*\])/i,/^(?:[^:\n\s\-\{]+)/i,/^(?:\s*:(?:[^:\n;]|:[^:\n;])+)/i,/^(?:-->)/i,/^(?:--)/i,/^(?::::)/i,/^(?:$)/i,/^(?:.)/i],conditions:{LINE:{rules:[10,11,12],inclusive:!1},struct:{rules:[10,11,12,23,27,30,36,43,44,45,46,56,57,58,72,73,74,75,76,77],inclusive:!1},FLOATING_NOTE_ID:{rules:[65],inclusive:!1},FLOATING_NOTE:{rules:[62,63,64],inclusive:!1},NOTE_TEXT:{rules:[67,68],inclusive:!1},NOTE_ID:{rules:[66],inclusive:!1},NOTE:{rules:[59,60,61],inclusive:!1},STYLEDEF_STYLEOPTS:{rules:[],inclusive:!1},STYLEDEF_STYLES:{rules:[32],inclusive:!1},STYLE_IDS:{rules:[],inclusive:!1},STYLE:{rules:[31],inclusive:!1},CLASS_STYLE:{rules:[29],inclusive:!1},CLASS:{rules:[28],inclusive:!1},CLASSDEFID:{rules:[26],inclusive:!1},CLASSDEF:{rules:[24,25],inclusive:!1},acc_descr_multiline:{rules:[21,22],inclusive:!1},acc_descr:{rules:[19],inclusive:!1},acc_title:{rules:[17],inclusive:!1},SCALE:{rules:[14,15,34,35],inclusive:!1},ALIAS:{rules:[],inclusive:!1},STATE_ID:{rules:[49],inclusive:!1},STATE_STRING:{rules:[50,51],inclusive:!1},FORK_STATE:{rules:[],inclusive:!1},STATE:{rules:[10,11,12,37,38,39,40,41,42,47,48,52,53,54,55],inclusive:!1},ID:{rules:[10,11,12],inclusive:!1},INITIAL:{rules:[0,1,2,3,4,5,6,7,8,9,11,12,13,16,18,20,23,27,30,33,36,55,58,69,70,71,72,73,74,75,77,78,79],inclusive:!0}}};return V})();kt.lexer=ke;function dt(){this.yy={}}return p(dt,"Parser"),dt.prototype=kt,kt.Parser=dt,new dt})();xt.parser=xt;var ve=xt,De="TB",ne="TB",te="dir",Q="state",q="root",Lt="relation",Ce="classDef",Ae="style",xe="applyClass",rt="default",oe="divider",le="fill:none",ce="fill: #333",he="c",de="markdown",ue="normal",Ct="rect",At="rectWithTitle",Le="stateStart",we="stateEnd",wt="divider",ee="roundedWithTitle",Ie="note",Ne="noteGroup",it="statediagram",Oe="state",Re=`${it}-${Oe}`,fe="transition",$e="note",Fe="note-edge",Pe=`${fe} ${Fe}`,Be=`${it}-${$e}`,Ge="cluster",Ye=`${it}-${Ge}`,Ve="cluster-alt",Me=`${it}-${Ve}`,pe="parent",Se="note",We="state",It="----",je=`${It}${Se}`,se=`${It}${pe}`,mt=new Map,W=0,ge=0,tt=new Map,Ue=p((t,e,s,a)=>{if(t===wt&&s?.id!==void 0&&tt.has(s.id)){let d=tt.get(s.id);return tt.set(e,d),d}let i=ge++,h=a?void 0:i;return tt.set(e,h),h},"colorSlotFor");function bt(t="",e=0,s="",a=It){let i=s!==null&&s.length>0?`${a}${s}`:"";return`${We}-${t}${i}-${e}`}p(bt,"stateDomId");var He=p((t,e,s,a,i,h,d,u)=>{E.trace("items",e),e.forEach(c=>{switch(c.stmt){case Q:st(t,c,s,a,i,h,d,u);break;case rt:st(t,c,s,a,i,h,d,u);break;case Lt:{st(t,c.state1,s,a,i,h,d,u),st(t,c.state2,s,a,i,h,d,u);let m=d==="neo",y={id:"edge"+W,start:c.state1.id,end:c.state2.id,arrowhead:"normal",arrowTypeEnd:m?"arrow_barb_neo":"arrow_barb",style:le,labelStyle:"",label:M.sanitizeText(c.description??"",$()),arrowheadStyle:ce,labelpos:he,labelType:de,thickness:ue,classes:fe,look:d};i.push(y),W++}break}})},"setupDoc"),re=p((t,e=ne)=>{let s=e;if(t.doc)for(let a of t.doc)a.stmt==="dir"&&(s=a.value);return s},"getDir");function et(t,e,s){if(!e.id||e.id==="</join></fork>"||e.id==="</choice>")return;e.cssClasses&&(Array.isArray(e.cssCompiledStyles)||(e.cssCompiledStyles=[]),e.cssClasses.split(" ").forEach(i=>{let h=s.get(i);h&&(e.cssCompiledStyles=[...e.cssCompiledStyles??[],...h.styles])}));let a=t.find(i=>i.id===e.id);a?Object.assign(a,e):t.push(e)}p(et,"insertOrUpdateNode");function ye(t){return t?.classes?.join(" ")??""}p(ye,"getClassesFromDbInfo");function me(t){return t?.styles??[]}p(me,"getStylesFromDbInfo");var st=p((t,e,s,a,i,h,d,u)=>{let c=e.id,m=s.get(c),y=ye(m),T=me(m),L=$(),O=y.trim()!==""||T.length>0;if(E.info("dataFetcher parsedItem",e,m,T),c!=="root"){let D=Ct;e.start===!0?D=Le:e.start===!1&&(D=we),e.type!==rt&&(D=e.type),mt.get(c)||mt.set(c,{id:c,shape:D,description:M.sanitizeText(c,L),cssClasses:`${y} ${Re}`,cssStyles:T});let S=mt.get(c);e.description&&(Array.isArray(S.description)?(S.shape=At,S.description.push(e.description)):S.description?.length&&S.description.length>0?(S.shape=At,S.description===c?S.description=[e.description]:S.description=[S.description,e.description]):(S.shape=Ct,S.description=e.description),S.description=M.sanitizeTextOrArray(S.description,L)),S.description?.length===1&&S.shape===At&&(S.type==="group"?S.shape=ee:S.shape=Ct),!S.type&&e.doc&&(E.info("Setting cluster for XCX",c,re(e)),S.type="group",S.isGroup=!0,S.dir=re(e),S.shape=e.type===oe?wt:ee,S.colorIndex=Ue(S.shape,c,t,O),S.cssClasses=`${S.cssClasses} ${Ye} ${h?Me:""}`);let w={labelStyle:"",shape:S.shape,label:S.description,cssClasses:S.cssClasses,cssCompiledStyles:[],cssStyles:S.cssStyles,id:c,dir:S.dir,domId:bt(c,W),type:S.type,isGroup:S.type==="group",colorIndex:S.colorIndex,padding:8,rx:10,ry:10,look:d,labelType:"markdown"};if(w.shape===wt&&(w.label=""),t&&t.id!=="root"&&(E.trace("Setting node ",c," to be child of its parent ",t.id),w.parentId=t.id),w.centerLabel=!0,e.note){let C={labelStyle:"",shape:Ie,label:e.note.text,labelType:"markdown",cssClasses:Be,cssStyles:[],cssCompiledStyles:[],id:c+je+"-"+W,domId:bt(c,W,Se),type:"node",isGroup:!1,padding:L.flowchart?.padding,look:d,position:e.note.position},F=c+se,I={labelStyle:"",shape:Ne,label:e.note.text,cssClasses:S.cssClasses,cssStyles:[],id:c+se,domId:bt(c,W,pe),type:"group",isGroup:!0,padding:16,look:d,position:e.note.position};W++,I.id=F,C.parentId=F,et(a,I,u),et(a,C,u),et(a,w,u);let P=c,v=C.id;e.note.position==="left of"&&(P=C.id,v=c),i.push({id:P+"-"+v,start:P,end:v,arrowhead:"none",arrowTypeEnd:"",style:le,labelStyle:"",classes:Pe,pattern:"dashed",arrowheadStyle:ce,labelpos:he,labelType:de,thickness:ue,look:d})}else et(a,w,u)}e.doc&&(E.trace("Adding nodes children "),He(e,e.doc,s,a,i,!h,d,u))},"dataFetcher"),ze=p(()=>{mt.clear(),W=0,ge=0,tt.clear()},"reset"),be=p((t,e=ne)=>{if(!t.doc)return e;let s=e;for(let a of t.doc)a.stmt==="dir"&&(s=a.value);return s},"getDir"),Ke=p(function(t,e){return e.db.getClasses()},"getClasses"),Xe=p(async function(t,e,s,a){E.info("REF0:"),E.info("Drawing state diagram (v2)",e);let{securityLevel:i,state:h,layout:d}=$();a.db.extract(a.db.getRootDocV2());let u=a.db.getData(),c=Qt(e,i);u.type=a.type,u.layoutAlgorithm=Jt(d),u.nodeSpacing=h?.nodeSpacing||50,u.rankSpacing=h?.rankSpacing||50,$().look==="neo"?u.markers=["barbNeo"]:u.markers=["barb"],u.diagramId=e,await Xt(u,c);let y=8;try{(typeof a.db.getLinks=="function"?a.db.getLinks():new Map).forEach((L,O)=>{let D=typeof O=="string"?O:typeof O?.id=="string"?O.id:"",S=u.nodes.find(v=>v.id===D);if(!D){E.warn("\u26A0\uFE0F Invalid or missing stateId from key:",JSON.stringify(O));return}let w=c.node()?.querySelectorAll("g.node, g.rough-node"),C;if(w?.forEach(v=>{let z=v.textContent?.trim();(v.id===S?.domId||z===D)&&(C=v)}),!C){E.warn("\u26A0\uFE0F Could not find node matching text:",D);return}let F=C.parentNode;if(!F){E.warn("\u26A0\uFE0F Node has no parent, cannot wrap:",D);return}let I=document.createElementNS("http://www.w3.org/2000/svg","a"),P=L.url.replace(/^"+|"+$/g,"");if(I.setAttributeNS("http://www.w3.org/1999/xlink","xlink:href",P),I.setAttribute("target","_blank"),L.tooltip){let v=L.tooltip.replace(/^"+|"+$/g,"");I.setAttribute("title",v),C.setAttribute("title",v)}F.replaceChild(I,C),I.appendChild(C),E.info("\u{1F517} Wrapped node in <a> tag for:",D,L.url)})}catch(T){E.error("\u274C Error injecting clickable links:",T)}jt.insertTitle(c,"statediagramTitleText",h?.titleTopMargin??25,a.db.getDiagramTitle()),Zt(c,y,it,h?.useMaxWidth??!0)},"draw"),Je={getClasses:Ke,draw:Xe,getDir:be},x={START_NODE:"[*]",START_TYPE:"start",END_NODE:"[*]",END_TYPE:"end",COLOR_KEYWORD:"color",FILL_KEYWORD:"fill",BG_FILL:"bgFill",STYLECLASS_SEP:","},ie=p(()=>new Map,"newClassesList"),ae=p(()=>({relations:[],states:new Map,documents:{}}),"newDoc"),yt=p(t=>JSON.parse(JSON.stringify(t)),"clone"),H,qe=(H=class{constructor(e){this.version=e,this.nodes=[],this.edges=[],this.rootDoc=[],this.classes=ie(),this.documents={root:ae()},this.currentDocument=this.documents.root,this.startEndCount=0,this.dividerCnt=0,this.links=new Map,this.funs=[],this.getAccTitle=Bt,this.setAccTitle=Pt,this.getAccDescription=Yt,this.setAccDescription=Gt,this.setDiagramTitle=Vt,this.getDiagramTitle=Mt,this.clear(),this.setRootDoc=this.setRootDoc.bind(this),this.getDividerId=this.getDividerId.bind(this),this.setDirection=this.setDirection.bind(this),this.trimColon=this.trimColon.bind(this),this.bindFunctions=this.bindFunctions.bind(this)}extract(e){this.clear(!0);for(let i of Array.isArray(e)?e:e.doc)switch(i.stmt){case Q:this.addState(i.id.trim(),i.type,i.doc,i.description,i.note);break;case Lt:this.addRelation(i.state1,i.state2,i.description);break;case Ce:this.addStyleClass(i.id.trim(),i.classes);break;case Ae:this.handleStyleDef(i);break;case xe:this.setCssClass(i.id.trim(),i.styleClass);break;case"click":this.addLink(i.id,i.url,i.tooltip);break}let s=this.getStates(),a=$();ze(),st(void 0,this.getRootDocV2(),s,this.nodes,this.edges,!0,a.look,this.classes);for(let i of this.nodes)if(Array.isArray(i.label)){if(i.description=i.label.slice(1),i.isGroup&&i.description.length>0)throw new Error(`Group nodes can only have label. Remove the additional description for node [${i.id}]`);i.label=i.label[0]}}handleStyleDef(e){let s=e.id.trim().split(","),a=e.styleClass.split(",");for(let i of s){let h=this.getState(i);if(!h){let d=i.trim();this.addState(d),h=this.getState(d)}h&&(h.styles=a.map(d=>d.replace(/;/g,"")?.trim()))}}setRootDoc(e){E.info("Setting root doc",e),this.rootDoc=e,this.version===1?this.extract(e):this.extract(this.getRootDocV2())}docTranslator(e,s,a){if(s.stmt===Lt){this.docTranslator(e,s.state1,!0),this.docTranslator(e,s.state2,!1);return}if(s.stmt===Q&&(s.id===x.START_NODE?(s.id=e.id+(a?"_start":"_end"),s.start=a):s.id=s.id.trim()),s.stmt!==q&&s.stmt!==Q||!s.doc)return;let i=[],h=[];for(let d of s.doc)if(d.type===oe){let u=yt(d);u.doc=yt(h),i.push(u),h=[]}else h.push(d);if(i.length>0&&h.length>0){let d={stmt:Q,id:Wt(),type:"divider",doc:yt(h)};i.push(yt(d)),s.doc=i}s.doc.forEach(d=>this.docTranslator(s,d,!0))}getRootDocV2(){return this.docTranslator({id:q,stmt:q},{id:q,stmt:q,doc:this.rootDoc},!0),{id:q,doc:this.rootDoc}}addState(e,s=rt,a=void 0,i=void 0,h=void 0,d=void 0,u=void 0,c=void 0){let m=e?.trim();if(!this.currentDocument.states.has(m))E.info("Adding state ",m,i),this.currentDocument.states.set(m,{stmt:Q,id:m,descriptions:[],type:s,doc:a,note:h,classes:[],styles:[],textStyles:[]});else{let y=this.currentDocument.states.get(m);if(!y)throw new Error(`State not found: ${m}`);y.doc||(y.doc=a),y.type||(y.type=s)}if(i&&(E.info("Setting state description",m,i),(Array.isArray(i)?i:[i]).forEach(T=>this.addDescription(m,T.trim()))),h){let y=this.currentDocument.states.get(m);if(!y)throw new Error(`State not found: ${m}`);y.note=h,y.note.text=M.sanitizeText(y.note.text,$())}d&&(E.info("Setting state classes",m,d),(Array.isArray(d)?d:[d]).forEach(T=>this.setCssClass(m,T.trim()))),u&&(E.info("Setting state styles",m,u),(Array.isArray(u)?u:[u]).forEach(T=>this.setStyle(m,T.trim()))),c&&(E.info("Setting state styles",m,u),(Array.isArray(c)?c:[c]).forEach(T=>this.setTextStyle(m,T.trim())))}clear(e){this.nodes=[],this.edges=[],this.funs=[this.setupToolTips.bind(this)],this.documents={root:ae()},this.currentDocument=this.documents.root,this.startEndCount=0,this.classes=ie(),e||(this.links=new Map,Ft())}getState(e){return this.currentDocument.states.get(e)}getStates(){return this.currentDocument.states}logDocuments(){E.info("Documents = ",this.documents)}getRelations(){return this.currentDocument.relations}addLink(e,s,a){this.links.set(e,{url:s,tooltip:a}),E.warn("Adding link",e,s,a)}getLinks(){return this.links}startIdIfNeeded(e=""){return e===x.START_NODE?(this.startEndCount++,`${x.START_TYPE}${this.startEndCount}`):e}startTypeIfNeeded(e="",s=rt){return e===x.START_NODE?x.START_TYPE:s}endIdIfNeeded(e=""){return e===x.END_NODE?(this.startEndCount++,`${x.END_TYPE}${this.startEndCount}`):e}endTypeIfNeeded(e="",s=rt){return e===x.END_NODE?x.END_TYPE:s}addRelationObjs(e,s,a=""){let i=this.startIdIfNeeded(e.id.trim()),h=this.startTypeIfNeeded(e.id.trim(),e.type),d=this.startIdIfNeeded(s.id.trim()),u=this.startTypeIfNeeded(s.id.trim(),s.type);this.addState(i,h,e.doc,e.description,e.note,e.classes,e.styles,e.textStyles),this.addState(d,u,s.doc,s.description,s.note,s.classes,s.styles,s.textStyles),this.currentDocument.relations.push({id1:i,id2:d,relationTitle:M.sanitizeText(a,$())})}addRelation(e,s,a){if(typeof e=="object"&&typeof s=="object")this.addRelationObjs(e,s,a);else if(typeof e=="string"&&typeof s=="string"){let i=this.startIdIfNeeded(e.trim()),h=this.startTypeIfNeeded(e),d=this.endIdIfNeeded(s.trim()),u=this.endTypeIfNeeded(s);this.addState(i,h),this.addState(d,u),this.currentDocument.relations.push({id1:i,id2:d,relationTitle:a?M.sanitizeText(a,$()):void 0})}}addDescription(e,s){let a=this.currentDocument.states.get(e),i=s.startsWith(":")?s.replace(":","").trim():s;a?.descriptions?.push(M.sanitizeText(i,$()))}cleanupLabel(e){return e.startsWith(":")?e.slice(2).trim():e.trim()}getDividerId(){return this.dividerCnt++,`divider-id-${this.dividerCnt}`}addStyleClass(e,s=""){this.classes.has(e)||this.classes.set(e,{id:e,styles:[],textStyles:[]});let a=this.classes.get(e);s&&a&&s.split(x.STYLECLASS_SEP).forEach(i=>{let h=i.replace(/([^;]*);/,"$1").trim();if(RegExp(x.COLOR_KEYWORD).exec(i)){let u=h.replace(x.FILL_KEYWORD,x.BG_FILL).replace(x.COLOR_KEYWORD,x.FILL_KEYWORD);a.textStyles.push(u)}a.styles.push(h)})}getClasses(){return this.classes}setupToolTips(e){let s=qt();gt(e).select("svg").selectAll("g.node, g.rough-node").on("mouseover",h=>{let d=gt(h.currentTarget),u=d.attr("title");if(u===null)return;let c=h.currentTarget?.getBoundingClientRect();s.transition().duration(200).style("opacity",".9"),s.style("left",window.scrollX+c.left+(c.right-c.left)/2+"px").style("top",window.scrollY+c.bottom+"px"),s.html($t.sanitize(u)),d.classed("hover",!0)}).on("mouseout",h=>{s.transition().duration(500).style("opacity",0),gt(h.currentTarget).classed("hover",!1)})}setCssClass(e,s){e.split(",").forEach(a=>{let i=this.getState(a);if(!i){let h=a.trim();this.addState(h),i=this.getState(h)}i?.classes?.push(s)})}setStyle(e,s){this.getState(e)?.styles?.push(s)}setTextStyle(e,s){this.getState(e)?.textStyles?.push(s)}bindFunctions(e){this.funs.forEach(s=>{s(e)})}getDirectionStatement(){return this.rootDoc.find(e=>e.stmt===te)}getDirection(){return this.getDirectionStatement()?.value??De}setDirection(e){let s=this.getDirectionStatement();s?s.value=e:this.rootDoc.unshift({stmt:te,value:e})}trimColon(e){return e.startsWith(":")?e.slice(1).trim():e.trim()}getData(){let e=$();for(let s of this.nodes)s.wrappingWidth??(s.wrappingWidth=e.state?.wrappingWidth),s.isGroup||(s.minWidth??(s.minWidth=e.state?.minNodeWidth));return{nodes:this.nodes,edges:this.edges,other:{},config:e,direction:be(this.getRootDocV2())}}getConfig(){return $().state}},p(H,"StateDB"),H.relationType={AGGREGATION:0,EXTENSION:1,COMPOSITION:2,DEPENDENCY:3},H),Qe=p(t=>{let{theme:e,bkgColorArray:s,borderColorArray:a}=t;if(!Ht(e,a))return"";let i=zt(t.look),h=Ut(s),d="";for(let u=0;u<Kt(a);u++){let c=a[u],m=h?`fill: ${s[u%s.length]};`:"",y=`[data-look="${i}"][data-color-id="color-${u}"]`;d+=`

    /* The title strip: \`rect.outer\` spans the whole composite and \`rect.inner\` covers
       the body, so what stays visible of \`outer\` is the band behind the label. */
    ${y}.statediagram-cluster rect.outer {
      stroke: ${c};
      ${m}
    }

    ${y}.statediagram-cluster rect.inner {
      stroke: ${c};
    }

    /* Concurrency regions. Siblings of one composite share a slot, so a divided composite
       reads as one thing split into parts rather than as several composites. */
    ${y}.statediagram-cluster rect.divider {
      stroke: ${c};
      ${m}
    }

    /* handDrawn draws the same container as roughjs shapes rather than plain rects, so it
       needs its own rules. \`roundedWithTitle\` and \`divider\` name those groups \`outer\`,
       \`inner\` and \`divider\` to match the classic branch, which is what lets these
       discriminate -- a bare \`.statediagram-cluster path\` rule reached the body as well and
       tinted the whole composite, losing \`compositeBackground\` and diverging from what
       classic and neo do.

       roughjs emits two paths per shape and marks them: the filled shape carries
       \`stroke="none"\` and the sketched outline carries \`fill="none"\`. Splitting on that is
       what keeps \`fill\` off the outline -- a rough outline is open squiggles, not a closed
       region, so filling it produces smears -- and keeps \`stroke\` off the fill shape, which
       would otherwise gain an edge it was drawn without. */
    ${y}.statediagram-cluster .outer path[stroke='none'] {
      ${m}
    }

    ${y}.statediagram-cluster .outer path[fill='none'] {
      stroke: ${c};
    }

    /* No \`.inner\` rule on purpose. The body shape is left entirely alone under handDrawn,
       where a rect's \`inner\` counterpart cannot be recoloured safely: roughjs draws a
       hachure fill as *stroked* lines, so its fill paths carry \`fill="none"\` exactly like
       the outline and no selector separates them. An \`.inner\` stroke rule therefore
       repainted the hatching of every alt composite in the palette colour instead of
       leaving it on \`altBackground\`. The container still reads as palette-coloured: the
       \`outer\` shape spans the whole composite, so its outline already frames the body. */

    /* Regions split the same way, which is why \`divider\` fills solid rather than taking
       roughjs's default hachure -- see the note on that call. Hatched, both of its paths
       carried \`fill="none"\` and these two rules degenerated: the tint matched nothing and
       the border rule repainted the hatching. */
    ${y}.statediagram-cluster .divider path[stroke='none'] {
      ${m}
    }

    ${y}.statediagram-cluster .divider path[fill='none'] {
      stroke: ${c};
    }
    `}return d},"genColor"),Ze=p(t=>`
${Qe(t)}
defs [id$="-barbEnd"] {
    fill: ${t.transitionColor};
    stroke: ${t.transitionColor};
  }
g.stateGroup text {
  fill: ${t.nodeBorder};
  stroke: none;
  font-size: 10px;
}
g.stateGroup text {
  fill: ${t.textColor};
  stroke: none;
  font-size: 10px;

}
g.stateGroup .state-title {
  font-weight: bolder;
  fill: ${t.stateLabelColor};
}

g.stateGroup rect {
  fill: ${t.mainBkg};
  stroke: ${t.nodeBorder};
}

g.stateGroup line {
  stroke: ${t.lineColor};
  stroke-width: ${t.strokeWidth||1};
}

.transition {
  stroke: ${t.transitionColor};
  stroke-width: ${t.strokeWidth||1};
  fill: none;
}

.stateGroup .composit {
  fill: ${t.background};
  border-bottom: 1px
}

.stateGroup .alt-composit {
  fill: #e0e0e0;
  border-bottom: 1px
}

.state-note {
  stroke: ${t.noteBorderColor};
  fill: ${t.noteBkgColor};

  text {
    fill: ${t.noteTextColor};
    stroke: none;
    font-size: 10px;
  }
}

.stateLabel .box {
  stroke: none;
  stroke-width: 0;
  fill: ${t.mainBkg};
  opacity: 0.5;
}

.edgeLabel .label rect {
  fill: ${t.labelBackgroundColor};
  opacity: 0.5;
}
.edgeLabel {
  background-color: ${t.edgeLabelBackground};
  p {
    background-color: ${t.edgeLabelBackground};
  }
  rect {
    opacity: 0.5;
    background-color: ${t.edgeLabelBackground};
    fill: ${t.edgeLabelBackground};
  }
  text-align: center;
}
.edgeLabel .label text {
  fill: ${t.transitionLabelColor||t.tertiaryTextColor};
}
.label div .edgeLabel {
  color: ${t.transitionLabelColor||t.tertiaryTextColor};
}

.stateLabel text {
  fill: ${t.stateLabelColor};
  font-size: 10px;
  font-weight: bold;
}

.node circle.state-start {
  fill: ${t.specialStateColor};
  stroke: ${t.specialStateColor};
}

.node .fork-join {
  fill: ${t.specialStateColor};
  stroke: ${t.specialStateColor};
}

.node circle.state-end {
  fill: ${t.innerEndBackground};
  stroke: ${t.background};
  stroke-width: 1.5
}
.end-state-inner {
  fill: ${t.compositeBackground||t.background};
  // stroke: ${t.background};
  stroke-width: 1.5
}

.node rect {
  fill: ${t.stateBkg||t.mainBkg};
  stroke: ${t.stateBorder||t.nodeBorder};
  stroke-width: ${t.strokeWidth||1}px;
}
.node polygon {
  fill: ${t.mainBkg};
  stroke: ${t.stateBorder||t.nodeBorder};;
  stroke-width: ${t.strokeWidth||1}px;
}
[id$="-barbEnd"] {
  fill: ${t.lineColor};
}

.statediagram-cluster rect {
  fill: ${t.compositeTitleBackground};
  stroke: ${t.stateBorder||t.nodeBorder};
  stroke-width: ${t.strokeWidth||1}px;
}

.cluster-label, .nodeLabel {
  color: ${t.stateLabelColor};
  // line-height: 1;
}

.statediagram-cluster rect.outer {
  rx: 5px;
  ry: 5px;
}
.statediagram-state .divider {
  stroke: ${t.stateBorder||t.nodeBorder};
}

.statediagram-state .title-state {
  rx: 5px;
  ry: 5px;
}
.statediagram-cluster.statediagram-cluster .inner {
  fill: ${t.compositeBackground||t.background};
}
.statediagram-cluster.statediagram-cluster-alt .inner {
  fill: ${t.altBackground?t.altBackground:"#efefef"};
}

.statediagram-cluster .inner {
  rx:0;
  ry:0;
}

.statediagram-state rect.basic {
  rx: 5px;
  ry: 5px;
}
.statediagram-state rect.divider {
  stroke-dasharray: 10,10;
  fill: ${t.altBackground?t.altBackground:"#efefef"};
}

.note-edge {
  stroke-dasharray: 5;
}

.statediagram-note rect {
  fill: ${t.noteBkgColor};
  stroke: ${t.noteBorderColor};
  stroke-width: 1px;
  rx: 0;
  ry: 0;
}
.statediagram-note rect {
  fill: ${t.noteBkgColor};
  stroke: ${t.noteBorderColor};
  stroke-width: 1px;
  rx: 0;
  ry: 0;
}

.statediagram-note text {
  fill: ${t.noteTextColor};
}

.statediagram-note .nodeLabel {
  color: ${t.noteTextColor};
}
.statediagram .edgeLabel {
  color: red; // ${t.noteTextColor};
}

[id$="-dependencyStart"], [id$="-dependencyEnd"] {
  fill: ${t.lineColor};
  stroke: ${t.lineColor};
  stroke-width: ${t.strokeWidth||1};
}

.statediagramTitleText {
  text-anchor: middle;
  font-size: 18px;
  fill: ${t.textColor};
}

[data-look="neo"].statediagram-cluster rect {
  fill: ${t.mainBkg};
  stroke: ${t.useGradient?"url("+t.svgId+"-gradient)":t.stateBorder||t.nodeBorder};
  stroke-width: ${t.strokeWidth??1};
}
[data-look="neo"].statediagram-cluster rect.outer {
  rx: ${t.radius}px;
  ry: ${t.radius}px;
  filter: ${t.dropShadow?t.dropShadow.replace("url(#drop-shadow)",`url(${t.svgId}-drop-shadow)`):"none"}
}
`,"getStyles"),ts=Ze,Ts={parser:ve,get db(){return new qe(2)},renderer:Je,styles:ts,init:p(t=>{t.state||(t.state={}),t.state.arrowMarkerAbsolute=t.arrowMarkerAbsolute},"init")};export{Ts as diagram};
