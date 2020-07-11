// Copyright 2020 The TensorFlow Runtime Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// RUN: bef_executor $(bef_name %s) | FileCheck %s --dump-input=fail

// CHECK-LABEL: --- Running 'test_linear'
func @test_linear() {
  %ch0 = hex.new.chain

  // CHECK-NEXT: constructed vt.value(1)
  // CHECK-NEXT: move constructed vt.value(1)
  %v1 = "vt.constant"() { value = 1 : i32 } : () -> !vt.value

  // CHECK-NEXT: constructed vt.value(2)
  // CHECK-NEXT: move constructed vt.value(2)
  %v2 = "vt.constant"() { value = 2 : i32 } : () -> !vt.value

  // CHECK-NEXT: constructed vt.value(3)
  // CHECK-NEXT: move constructed vt.value(3)
  %r = "vt.add"(%v1, %v2) : (!vt.value,  !vt.value) -> !vt.value
  // CHECK-NEXT: destroyed vt.value(1)
  // CHECK-NEXT: destroyed vt.value(2)

  // CHECK-NEXT: print vt_value(3)
  "vt.print"(%r, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)
  // CHECK-NEXT: destroyed vt.value(3)

  // CHECK-NEXT: constructed vt.value(4)
  // CHECK-NEXT: move constructed vt.value(4)
  "vt.constant"() { value = 4 : i32 } : () -> !vt.value
  // CHECK-NEXT: destroyed vt.value(4)

  // CHECK-NEXT: constructed vt.value(5)
  // CHECK-NEXT: move constructed vt.value(5)
  "vt.constant"() { value = 5 : i32 } : () -> !vt.value
  // CHECK-NEXT: destroyed vt.value(5)
  hex.return
}

// CHECK-LABEL: --- Not running 'no_op' because it has arguments
func @no_op(%x: !vt.value) -> !vt.value {
  hex.return %x : !vt.value
}

// CHECK-LABEL: --- Running 'call_no_op'
func @call_no_op() {
  // This test uses one vt.value(2) that is all of these:
  // - Function argument: passed to no_op.
  // - Function result: returned by no_op.
  // - Op input: passed to hex.call.
  // - Op output: returned by hex.call.

  // CHECK-NEXT: constructed vt.value(2)
  // CHECK-NEXT: move constructed vt.value(2)
  %c1 = "vt.constant"() { value = 2 : i32 } : () -> !vt.value

  // no_op returns its argument, which extends vt.value(2)'s lifetime.
  %x = hex.call @no_op(%c1) : (!vt.value) -> !vt.value

  %ch0 = hex.new.chain

  // CHECK-NEXT: print vt_value(2)
  "vt.print"(%x, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)
  // CHECK-NEXT: destroyed vt.value(2)
  hex.return
}

// CHECK-LABEL: --- Not running 'add_one' because it has arguments
func @add_one(%x: !vt.value) -> !vt.value {
  %v1 = "vt.constant"() { value = 1 : i32 } : () -> !vt.value
  %r = "vt.add"(%v1, %x) : (!vt.value,  !vt.value) -> !vt.value
  hex.return %r : !vt.value
}

// CHECK-LABEL: --- Running 'caller'

func @caller() {
  // CHECK-NEXT: constructed vt.value(3)
  // CHECK-NEXT: move constructed vt.value(3)
  %c1 = "vt.constant"() { value = 3 : i32 } : () -> !vt.value

  // CHECK-NEXT: constructed vt.value(1)
  // CHECK-NEXT: move constructed vt.value(1)

  // CHECK-NEXT: constructed vt.value(4)
  // CHECK-NEXT: move constructed vt.value(4)
  // CHECK-NEXT: destroyed vt.value(1)

  %x = hex.call @add_one(%c1) : (!vt.value) -> !vt.value

  // TODO: If calls were non-strict, then 3 could be destroyed at the add,
  // before the return.
  // CHECK-NEXT: destroyed vt.value(3)

  %ch0 = hex.new.chain

  // CHECK-NEXT: print vt_value(4)
  "vt.print"(%x, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)
  // CHECK-NEXT: destroyed vt.value(4)
  hex.return
}

// CHECK-NEXT: --- Running 'test_hello'
func @test_hello() {
 // CHECK: hello host executor!
  %ch0 = hex.new.chain
  %ch1 = "tfrt_test.print_hello"(%ch0) : (!hex.chain) -> !hex.chain
  hex.return
}

// CHECK-LABEL: --- Running 'share_to_two'
func @share_to_two() {
  // CHECK-NEXT: constructed vt.value(1)
  // CHECK-NEXT: move constructed vt.value(1)
  %c1 = "vt.constant"() { value = 1 : i32 } : () -> !vt.value

  %x1, %x2 = "tfrt_test.share_to_two"(%c1) : (!vt.value) -> (!vt.value, !vt.value)

  %ch0 = hex.new.chain

  // CHECK-NEXT: print vt_value(1)
  "vt.print"(%x1, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)

  // CHECK-NEXT: print vt_value(1)
  "vt.print"(%x2, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)

  // CHECK-NEXT: destroyed vt.value(1)
  hex.return
}

// Testing calling a bef function that forwards its argument into two results.

// CHECK-LABEL: --- Not running 'call_share_to_two' because it has arguments
func @call_share_to_two(%x: !vt.value) -> (!vt.value, !vt.value) {
  %x1, %x2 = "tfrt_test.share_to_two"(%x) : (!vt.value) -> (!vt.value, !vt.value)
  hex.return %x1, %x2 : !vt.value, !vt.value
}

// CHECK-LABEL: --- Running 'share_to_two_caller'
func @share_to_two_caller() {
  // CHECK-NEXT: constructed vt.value(1)
  // CHECK-NEXT: move constructed vt.value(1)
  %c1 = "vt.constant"() { value = 1 : i32 } : () -> !vt.value

  %x1, %x2 = hex.call @call_share_to_two(%c1) : (!vt.value) -> (!vt.value, !vt.value)

  %ch0 = hex.new.chain

  // CHECK-NEXT: print vt_value(1)
  "vt.print"(%x1, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)

  // CHECK-NEXT: print vt_value(1)
  "vt.print"(%x2, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)

  // CHECK-NEXT: destroyed vt.value(1)
  hex.return
}

// CHECK-LABEL: --- Not running 'repeat_n_inc' because it has arguments
func @repeat_n_inc(%n: i32) -> () {
  // Returns 1 + %n by initializing %x to 1 and incrementing in a loop.
  %ch0 = hex.new.chain
  %x = "vt.constant"() { value = 1 : i32 } : () -> !vt.value
  %y = hex.repeat.i32 %n, %x : !vt.value {
      %v1 = "vt.constant"() { value = 1 : i32 } : () -> !vt.value
      %r = "vt.add"(%v1, %x) : (!vt.value,  !vt.value) -> !vt.value
      hex.return %r : !vt.value
  }

  "vt.print"(%y, %ch0) : (!vt.value, !hex.chain) -> (!hex.chain)

  hex.return
}

// CHECK-LABEL: --- Running 'repeat_0_inc'
func @repeat_0_inc() {
  %count = hex.constant.i32 0

  // CHECK: print vt_value(1)
  // CHECK-NEXT: destroyed vt.value(1)
  hex.call @repeat_n_inc(%count) : (i32) -> ()

  hex.return
}

// CHECK-LABEL: --- Running 'repeat_1_inc'
func @repeat_1_inc() {
  %count = hex.constant.i32 1

  // CHECK: print vt_value(2)
  // CHECK-NEXT: destroyed vt.value(2)
  hex.call @repeat_n_inc(%count) : (i32) -> ()
  hex.return
}

// CHECK-LABEL: --- Running 'repeat_2_inc'
func @repeat_2_inc() {
  %count = hex.constant.i32 2

  // CHECK: print vt_value(3)
  // CHECK-NEXT: destroyed vt.value(3)
  hex.call @repeat_n_inc(%count) : (i32) -> ()
  hex.return
}
