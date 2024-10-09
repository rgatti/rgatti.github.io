+++
title = 'Kotlin Coroutine Notes'
date = 2024-10-08T19:18:28-05:00
draft = false
summary = 'On going collection of notes about Coroutines.'
description = 'On going collection of notes about Coroutines.'
toc = true
readTime = true
autonumber = false
math = false
tags = ['kotlin']
showTags = true
hideBackToTop = false
+++

## Concurrency

![concurrent vs parallel](concurrent-vs-parallel.svg)

## Coroutines

[Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html) are a "suspendable computation".

* This is a language level concept - the operating system scheduler has no idea coroutines exist.
* Most of the time there's a _M:N_ mapping of Coroutines to system threads.
* Different coroutine dispatchers use different thread pools.

![model](coroutine-model.svg)

Each coroutine is created inside a [`CoroutineScope`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-coroutine-scope/). Multiple coroutines can be created inside the same scope. The `CoroutineScope`'s main purpose is to provide coroutine builder functions like [`launch`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/launch.html) and [`async`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/async.html) which delimite the lifetime of coroutines.

The scope also acts as a wrapper around other data structures related to the coroutines inside it such as the `CoroutineContext`.

The [`CoroutineContext`](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.coroutines/-coroutine-context/) is a kind of map that uses object types as [keys](https://kotlinlang.org/api/core/kotlin-stdlib/kotlin.coroutines/-coroutine-context/-key/) to hold properites related to the scope it's in. The only property that should be accessed is the [Job](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-job/).

Jobs are used for [structural concurrency](https://kotlinlang.org/docs/coroutines-basics.html#structured-concurrency). They handle the lifecycle state of the coroutine. Jobs can be [lazy started](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-coroutine-start/-l-a-z-y/) which allows creating the coroutine upfront but only starting it when needed. Jobs can also be [canceled](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/cancel-and-join.html).

### Canceling Jobs

When a job is canceled, all of its children are also canceled. This code creates a tree of 3 coroutines with one parent and two children.

```kotlin
fun main() = runBlocking<Unit> {
    val job1 = launch {
        println("starting 1")

        launch {
            println("starting 1.1")
            delay(3.seconds)
            println("done 1.1")
        }
        launch {
            println("starting 1.2")
            delay(3.seconds)
            println("done 1.2")
        }

        delay(1.seconds)
        println("done 1")
    }

    delay(2.seconds)
    println("job 1 active: ${job1.isActive}")
    job1.cancelAndJoin()
}
```

Even though the parent (job1) completes it is still active waiting on the children to complete. When `job1` is canceled the children will also be canceled completing the coroutine.

The output is:

```
starting 1
starting 1.1
starting 1.2
job 1 active: true
done 1
```

### Shared mutable state

[Kotlin doc](https://kotlinlang.org/docs/shared-mutable-state-and-concurrency.html)

Coroutines will capture their context but just like threads, variables outside of the scope are shared and access must be synchronized with

* [`Atomic*` classes](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/atomic/package-summary.html)
* [thread isolation](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/new-single-thread-context.html)
* [mutexes](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.sync/-mutex/)

In the following code the `internalData` is thread-safe for the wrapped coroutines (inside `launch`) but the `externalData` is not.
Access to `externalData` would require some form of synchronization.

```kotlin
var externalData = 0

fun main() = runBlocking {
    launch {
        var internalData = 0
    }
}
```

### Exception Handling

```kotlin
fun main() = runBlocking<Unit> {
    runCatching {
        coroutineScope {
            launch {
                val proc1 = async {
                    delay(1.seconds)
                    println("done task 1.1")
                    1
                }
                val proc2 = async {
                    delay(2.seconds)
                    throw Exception("boom!")

                    //never reached
                    println("done task 1.2")
                    2
                }

                // not the same as `this.map { it.await() }`
                val (result1, result2) = listOf(proc1, proc2).awaitAll()
                println("result is: ${result1 + result2}")
            }

            launch {
                delay(3.seconds)
                println("done task 2")
            }
        }
    }
    println("done")
}
```

## Flows

TODO

## Channels

[Channels](https://kotlinlang.org/docs/channels.html) are like a [`BlockingQueue`](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/BlockingQueue.html) in that message can be put onto a channel and depending on the channel configuration will:

* block until there's a receiver actively polling for new messages ([`RENDEZVOUS`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.channels/-channel/-factory/-r-e-n-d-e-z-v-o-u-s.html))
* block until there's capacity in the channel ([`BUFFERED`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.channels/-channel/-factory/-b-u-f-f-e-r-e-d.html))
* always succeed ([`CONFLATED`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.channels/-channel/-factory/-c-o-n-f-l-a-t-e-d.html) or [`UNLIMITED`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines.channels/-channel/-factory/-u-n-l-i-m-i-t-e-d.html))

Channels are used for communicating between coroutines in an asynchronous, thread-safe way.

Channels are single message type only. Meaning, when creating a channel the type of data being passed on it must be defined but inheritance is allowed.

```kotlin
data class Message(val id: Int, val message: String)

// create a rendezvous channel
val channel = Channel<Message>()
```

Channels can be used in normal 1:1, fan-in, and fan-out models.

Any read operation on a channel will consume the messages. This means, two separate channels are needed for bidirectional communication between coroutines.

Reading from a channel can be done in a normal `for` loop. When done this way, closing the channel will automatically exit the loop.

```kotlin
for(message in channel) {
    // process message
}
```

## Testing

Use [`runTest`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/kotlinx.coroutines.test/run-test.html) when creating unit tests for coroutines. This behaves like [`runBlocking`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/run-blocking.html) except that it will skip delays.

Use [`StandardTestDispatcher`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/kotlinx.coroutines.test/-standard-test-dispatcher.html) in combination with [`TestCoroutineScheduler`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/kotlinx.coroutines.test/-test-coroutine-scheduler/) to override uses of custom dispatchers in tested code. This will order coroutine execution in a known way and allow stepping through time.

Use [`advanceUntilIdel`](https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-test/kotlinx.coroutines.test/-test-coroutine-scheduler/advance-until-idle.html) to move the virtual time forward until there are no more tasks queued in the scheduler.
