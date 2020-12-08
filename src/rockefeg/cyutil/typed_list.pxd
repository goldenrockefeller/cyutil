cdef class BaseReadableTypedList: # For Readonly List
    cpdef shallow_copy(self, copy_obj = ?)

    cpdef item(self, Py_ssize_t id)
    cpdef list items_shallow_copy(self)

    cpdef Py_ssize_t count(self, item) except *
    cpdef Py_ssize_t index(self, item) except *

    cpdef tuple full_type(self)
    cpdef item_type(self)

cdef class BaseWritableTypedList(BaseReadableTypedList): # For either FixedLenTypedList or TypedList
    cpdef void set_item(self, Py_ssize_t id, item) except *
    cpdef void set_items(self, list items) except *

    cpdef void reverse(self)

cdef class TypedList(BaseWritableTypedList):
    cdef __item_type
    cdef list __items

    cpdef void append(self, item) except *
    cpdef void extend(self, typed_list) except *
    cpdef void insert(self, Py_ssize_t id, item) except *
    cpdef pop(self, Py_ssize_t id = ?)
    cpdef void remove(self, item) except *

    cpdef list _items(self)

cdef TypedList new_TypedList(object item_type)
cdef void init_TypedList(TypedList typed_list, object item_type) except *

cdef class FixedLenTypedList(BaseWritableTypedList):
    cdef __typed_list

    cpdef typed_list_shallow_copy(self)

    cpdef _typed_list(self)

cdef FixedLenTypedList new_FixedLenTypedList(TypedList typed_list)
cdef void init_FixedLenTypedList(
    FixedLenTypedList fixed_list,
    TypedList typed_list
    ) except *

# Todo: ReadOnlyList
# Todo: Full type can include len

cpdef bint is_valid_item_type(item_type) except *
cpdef bint is_instance(item, target_type) except *
cpdef bint is_sub_full_type(full_type, target_full_type) except *
