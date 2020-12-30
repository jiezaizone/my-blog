---
layout: post
title:  "Vue3新特性一些问题思考"
date:   2020-12-22 12:08
categories: Vue
type: 技术
permalink: /archivers/vue/vue3
---

上一周做了一次技术分享，是关于Vue3的新特性。目前demo已经上传github，可以在这里去看：

![Vue3练习demo][07]

虽然在分享之前我已经无数次地自问自答，设想一切能够想到的问题。但是同事们的提问还是给了我很多的启发。


现将这些问题做一个记录。

## 问题

1. [生命周期函数被分离成公共部分之后，会不会和原本组件的生命周期函数互相影响？](#influnce)

2. [Vuex和响应式处理后的localstorage在公共对象管理方面的区别？](#vuex)

3. [Vue2和Vue3性能方面的异同？](#performance)

4. [Vue3的函数使用与mixin的区别,有什么优劣势？](#mixin)

### <span id="influnce">生命周期函数被分离成公共部分之后，会不会和原本组件的生命周期函数互相影响？</span>

答案是不会。

公共js里面的生命周期函数和页面的生命周期函数会根据所处位置依次加载。

来看下页面代码：

```javascript
// TodoMvcDemo.vue文件
import useScroll from '../composition/scroll'
setup() {
    ...
    const {top} = useScroll()
    onMounted (() => {
        console.log('.vue onMounted')
    })
}

```
下面是被抽离出来的公共代码：
```javascript
// scroll.js文件
import { ref, onMounted, onUnmounted } from 'vue'
export default function scroll() {
  const top = ref(0)

  const update = () => {
    top.value = window.scrollY
  }

  onMounted(()=> {
    console.log('.js onMounted')
    window.addEventListener('scroll', update)
  })


  onUnmounted(() => {
    window.removeEventListener('scroll', update)
  })
  return { top }
}

```
结果为：

![onMounted][01]


### <span id='vuex'>Vuex和响应式处理后的localstorage在公共对象管理方面的区别？</span>

响应式处理后的`localstorage`某种程度上有点像`vuex`实时对公共状态进行变更，不过`localstorage`是本地存储，不会因为项目停掉而丢失，而vuex则必须随vue项目一起运行使用。

### <span id='performance'>Vue2和Vue3性能方面的异同？</span>

根据尤大的介绍，Vue3相比于Vue2在性能方面的提升主要体现在：

* diff方法优化
* 变量静态提升
* cacheHandlers 事件侦听器缓存
* ssr渲染

下面一一来介绍下。

#### diff方法优化

在介绍diff方法优化之前，先解释下什么是`diff`。大家知道直接渲染dom开销是很大的，比如我们改动了一点数据，如果直接渲染在dom树上面，会引起整个dom树的重新编绘，非常耗时。

那么有没有一种办法，能够只更新我们修改的数据所在的dom节点，而不是更新整个dom树呢？`diff`算法可以帮我们做到这一点。在真实dom的基础上生成虚拟dom树（`Vitural dom`)，一旦数据有改变，就在虚拟dom上面去生成一个新的虚拟节点，将新的虚拟节点直接修改到真实的dom上面去，同时替换掉原来的旧的虚拟节点。`diff`方法就是通过一些算法，一边比较新旧节点的差异，一边对真实dom打补丁的操作。

那么Vue3在`diff`方法上有哪些优化呢？我们先来看一个例子。

![首页描述][02]

我们首先创建了一个`div`，可以看到编译文件的`render`函数里面调用`_openBlock`和`_createBlock`方法创建了一个名为‘div’的block，你可以把它看成是一个盒子或者一个块，用来存放虚拟节点。
`div`里面除了一个`span`是动态节点，其他`span`都是静态节点。

动态节点后面有一个尾巴，由数字1和一串描述/\*Text\*/组成。这个尾巴叫做`patchFlag`，`patchFlag`是一个由大于0的数字和描述性的文字组成的专门标记动态节点和属性的标志。每个数字都代表不同的类型。

因为静态节点一般不会变化，Vue3在diff更新的时候，不管动态节点前面有多少静态节点，也不管动态节点嵌套多深，会跳过不带`patchFla`g的静态节点，直接定位到带有`patchFlag`的动态节点，后续直接追踪动态节点。

Vue2无法做到这一点，虽然已经尽可能减少dom树的更新，但是有更改的节点对应的当前dom还是会一一去检测每个元素是否有变化。Vue3就突破了Vue2的这个性能瓶颈，更新速度提升了1.3-2倍。

#### 变量静态提升

来看下面的例子：

![hoistStatic][03]

在这里我们对编译过的文件进行了变量提升，原本在虚拟dom里面的静态节点被提升到`render`函数外面。

这样做的一大好处就是，静态节点只有在应用创建的时候会被创建一遍，后续渲染的话，这些节点就直接被调用了，可以大大地提升运行时的性能。

那么为什么能提升运行时的性能呢？

原本Vue2里面局部虚拟dom里面有任何一个节点发生了改变，那么就会删掉原本的旧的虚拟dom，创建新的虚拟dom，此过程就会不停地有节点被销毁和创建。虽然javascript做这些很快，但是如果应用如果变的很大了还是会对性能造成一定的影响。

#### cacheHandlers事件侦听器缓存

一般节点绑定的函数是固定的。在Vue2中，节点绑定的事件，每次触发都会生成全新的function去更新。Vue3中则提供了一个`cacheHandlers`事件侦听器，当`cacheHandlers`开启的时候，编译时会自动生成一个内联函数，将其变成静态节点，当事件再次触发的时候，就无需重新创建事件。

未开启`cacheHandlers`时：

![cacheHandlers未开启][04]

可以看到事件被当成动态节点使用`patchFlag`标记起来了。

开启`cacheHandlers`时：

![cacheHandlers开启][05]

开启之后，渲染函数里面生成内联函数将click事件缓存起来了。

#### SSR缓存

在介绍SSR（服务端渲染）优化之前，先介绍下什么是服务器端渲染（SSR), Vue.js是构建客户端应用程序的框架。默认情况下，可以在浏览器中输出Vue组件，进行生成Dom和操作Dom。然而，也可以将同一个组件渲染为服务器端的HTML字符串，将它们直接发送到浏览器，然后将这些静态标记“激活”为客户端上完全可交互的应用程序。

通过SSR可以使用户更快地看到完整渲染的页面，对于那些内容到达时间和转化率直接相关的应用程序而言，服务器端渲染至关重要。

Vue3在服务端渲染HTML字符串时，只有动态节点和属性才会以单独的字符串内嵌进去，其余静态节点一律以文本存在，这个性能肯定比转为VDom再转为HTML快的多。

![cacheHandlers开启][05]

Vue3在性能优化方面有很多的思想都很值得借鉴，我们通过学习，可以了解到如果陷入瓶颈的时候，也许换个思路就可以柳暗花明又一村。

### <span id="mixin">Vue3的函数使用与mixin的区别,有什么优劣势？</span>

Vue3里面使用Setup()函数可以在同一个入口里面对属性及其操作进行统一处理。遇到一些多个页面都能用到的公共方法还可以抽离出去。那么Vue3的公共函数和mixin相比有哪些好处呢？

1. 使用mixin语义化不明显，会将js整个合到页面里面去，不能够很快明白使用mixin函数的意义。而Vue3的公共函数引用作用一目了然。
2. 使用mixin遇到重名的函数会被覆盖，而Vue3的公共函数引入则可以按需引入，可以避免被覆盖的情况。

### 总结

以上呢就是关于Vue3分享的一些答疑点。同事们的问题促进我进一步去思考，让我对Vue3的理解更加深入了。同时深刻感觉，学习厉害的人的思路，可以开拓视野范围。

[01]:../../../images/onmount.png "onMounted"
[02]:../../../images/diff.png "diff"
[03]:../../../images/hoistStatic.png "hoistStatic"
[04]:../../../images/cache1.png "cacheHandlers未开启"
[05]:../../../images/cache2.png "cacheHandlers开启"
[06]:../../../images/ssr.png "SSR服务端渲染"
[07]:https://github.com/wuliya1994/Vue3-demo "Vue3练习demo"