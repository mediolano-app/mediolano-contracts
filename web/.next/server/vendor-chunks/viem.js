"use strict";
/*
 * ATTENTION: An "eval-source-map" devtool has been used.
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file with attached SourceMaps in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
exports.id = "vendor-chunks/viem";
exports.ids = ["vendor-chunks/viem"];
exports.modules = {

/***/ "(ssr)/./node_modules/viem/_esm/utils/unit/formatUnits.js":
/*!**********************************************************!*\
  !*** ./node_modules/viem/_esm/utils/unit/formatUnits.js ***!
  \**********************************************************/
/***/ ((__unused_webpack___webpack_module__, __webpack_exports__, __webpack_require__) => {

eval("__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   formatUnits: () => (/* binding */ formatUnits)\n/* harmony export */ });\n/**\n *  Divides a number by a given exponent of base 10 (10exponent), and formats it into a string representation of the number..\n *\n * - Docs: https://viem.sh/docs/utilities/formatUnits\n *\n * @example\n * import { formatUnits } from 'viem'\n *\n * formatUnits(420000000000n, 9)\n * // '420'\n */\nfunction formatUnits(value, decimals) {\n    let display = value.toString();\n    const negative = display.startsWith('-');\n    if (negative)\n        display = display.slice(1);\n    display = display.padStart(decimals, '0');\n    let [integer, fraction] = [\n        display.slice(0, display.length - decimals),\n        display.slice(display.length - decimals),\n    ];\n    fraction = fraction.replace(/(0+)$/, '');\n    return `${negative ? '-' : ''}${integer || '0'}${fraction ? `.${fraction}` : ''}`;\n}\n//# sourceMappingURL=formatUnits.js.map//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiKHNzcikvLi9ub2RlX21vZHVsZXMvdmllbS9fZXNtL3V0aWxzL3VuaXQvZm9ybWF0VW5pdHMuanMiLCJtYXBwaW5ncyI6Ijs7OztBQUFBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBLFlBQVksY0FBYztBQUMxQjtBQUNBO0FBQ0E7QUFDQTtBQUNPO0FBQ1A7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQTtBQUNBO0FBQ0E7QUFDQSxjQUFjLG9CQUFvQixFQUFFLGVBQWUsRUFBRSxlQUFlLFNBQVMsT0FBTztBQUNwRjtBQUNBIiwic291cmNlcyI6WyJ3ZWJwYWNrOi8vbWVkaW9sYW5vLy4vbm9kZV9tb2R1bGVzL3ZpZW0vX2VzbS91dGlscy91bml0L2Zvcm1hdFVuaXRzLmpzP2RiOGIiXSwic291cmNlc0NvbnRlbnQiOlsiLyoqXG4gKiAgRGl2aWRlcyBhIG51bWJlciBieSBhIGdpdmVuIGV4cG9uZW50IG9mIGJhc2UgMTAgKDEwZXhwb25lbnQpLCBhbmQgZm9ybWF0cyBpdCBpbnRvIGEgc3RyaW5nIHJlcHJlc2VudGF0aW9uIG9mIHRoZSBudW1iZXIuLlxuICpcbiAqIC0gRG9jczogaHR0cHM6Ly92aWVtLnNoL2RvY3MvdXRpbGl0aWVzL2Zvcm1hdFVuaXRzXG4gKlxuICogQGV4YW1wbGVcbiAqIGltcG9ydCB7IGZvcm1hdFVuaXRzIH0gZnJvbSAndmllbSdcbiAqXG4gKiBmb3JtYXRVbml0cyg0MjAwMDAwMDAwMDBuLCA5KVxuICogLy8gJzQyMCdcbiAqL1xuZXhwb3J0IGZ1bmN0aW9uIGZvcm1hdFVuaXRzKHZhbHVlLCBkZWNpbWFscykge1xuICAgIGxldCBkaXNwbGF5ID0gdmFsdWUudG9TdHJpbmcoKTtcbiAgICBjb25zdCBuZWdhdGl2ZSA9IGRpc3BsYXkuc3RhcnRzV2l0aCgnLScpO1xuICAgIGlmIChuZWdhdGl2ZSlcbiAgICAgICAgZGlzcGxheSA9IGRpc3BsYXkuc2xpY2UoMSk7XG4gICAgZGlzcGxheSA9IGRpc3BsYXkucGFkU3RhcnQoZGVjaW1hbHMsICcwJyk7XG4gICAgbGV0IFtpbnRlZ2VyLCBmcmFjdGlvbl0gPSBbXG4gICAgICAgIGRpc3BsYXkuc2xpY2UoMCwgZGlzcGxheS5sZW5ndGggLSBkZWNpbWFscyksXG4gICAgICAgIGRpc3BsYXkuc2xpY2UoZGlzcGxheS5sZW5ndGggLSBkZWNpbWFscyksXG4gICAgXTtcbiAgICBmcmFjdGlvbiA9IGZyYWN0aW9uLnJlcGxhY2UoLygwKykkLywgJycpO1xuICAgIHJldHVybiBgJHtuZWdhdGl2ZSA/ICctJyA6ICcnfSR7aW50ZWdlciB8fCAnMCd9JHtmcmFjdGlvbiA/IGAuJHtmcmFjdGlvbn1gIDogJyd9YDtcbn1cbi8vIyBzb3VyY2VNYXBwaW5nVVJMPWZvcm1hdFVuaXRzLmpzLm1hcCJdLCJuYW1lcyI6W10sInNvdXJjZVJvb3QiOiIifQ==\n//# sourceURL=webpack-internal:///(ssr)/./node_modules/viem/_esm/utils/unit/formatUnits.js\n");

/***/ })

};
;