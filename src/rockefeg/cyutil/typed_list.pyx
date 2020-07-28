cimport cython

cdef class BaseReadableTypedList: # For Readonly List
    cpdef shallow_copy(self, copy_obj = None):
        raise NotImplementedError("Abstract method.")

    cpdef item(self, Py_ssize_t id):
        raise NotImplementedError("Abstract method.")

    cpdef list items_shallow_copy(self):
        raise NotImplementedError("Abstract method.")

    cpdef Py_ssize_t count(self, item) except *:
        raise NotImplementedError("Abstract method.")

    cpdef Py_ssize_t index(self, item) except *:
        raise NotImplementedError("Abstract method.")

    cpdef tuple full_type(self):
        raise NotImplementedError("Abstract method.")

    cpdef item_type(self):
        raise NotImplementedError("Abstract method.")

cdef class BaseWritableTypedList(BaseReadableTypedList): # For
    cpdef void set_item(self, Py_ssize_t id, item) except *:
        raise NotImplementedError("Abstract method.")

    cpdef void set_items(self, list items) except *:
        raise NotImplementedError("Abstract method.")

    cpdef void reverse(self):
        raise NotImplementedError("Abstract method.")


@cython.warn.undeclared(True)
@cython.auto_pickle(True)
cdef class TypedList(BaseWritableTypedList):
    def __init__(self, item_type):
        init_TypedList(self, item_type)

    cpdef shallow_copy(self, copy_obj = None):
        cdef TypedList new_list
        cdef list items

        if copy_obj is None:
            new_list = TypedList.__new__(TypedList)
        else:
            new_list = copy_obj

        items = self.__items
        new_list.__items = items.copy()
        new_list.__item_type = self.__item_type

        return new_list

    def __len__(self):
        return len(self._items())

    def __contains__(self, item):
        return item in self._items()

    def __iter__(self):
        return iter(self._items())

    cpdef item(self, Py_ssize_t id):
        cdef list items

        items = self._items()

        return items[id]

    cpdef list items_shallow_copy(self):
        cdef list items

        items = self._items()

        return items.copy()

    cpdef void set_item(self, Py_ssize_t id, item) except *:
        cdef object self_item_type
        cdef object item_type
        cdef BaseReadableTypedList item_as_typed_list
        cdef list items

        self_item_type = self.item_type()
        items = self._items()

        if not is_instance(item, self_item_type):
            if isinstance(item, BaseReadableTypedList):
                item_as_typed_list = <BaseReadableTypedList?>item
                item_type = item_as_typed_list.full_type()
            else:
                item_type = type(item)

            raise (
                TypeError(
                    "The item (type(item) or? item.full_type() = {item_type}) "
                    "is not a subtype of the list's item type "
                    "(self.item_type() = {self_item_type} "
                    .format(**locals())))

        items[id] = item

    cpdef void set_items(self, list items) except *:
        cdef object item
        cdef object self_item_type
        cdef object item_type
        cdef BaseReadableTypedList item_as_typed_list

        self_item_type = self.item_type()

        for item in items:
            if not is_instance(item, self_item_type):
                if isinstance(item, BaseReadableTypedList):
                    item_as_typed_list = <BaseReadableTypedList?>item
                    item_type = item_as_typed_list.full_type()
                else:
                    item_type = type(item)

                raise (
                    TypeError(
                        "The item "
                        "(type(item) or? item.full_type() = {item_type}) "
                        "is not a subtype of the list's item type "
                        "(self.item_type() = {self_item_type} "
                        .format(**locals())))

        self.__items = items.copy()

    cpdef void append(self, item) except *:
        cdef object self_item_type
        cdef object item_type
        cdef BaseReadableTypedList item_as_typed_list

        self_item_type = self.item_type()

        if not is_instance(item, self_item_type):
            if isinstance(item, BaseReadableTypedList):
                item_as_typed_list = <BaseReadableTypedList?>item
                item_type = item_as_typed_list.full_type()
            else:
                item_type = type(item)

            raise (
                TypeError(
                    "The item (type(item) or? item.full_type() = {item_type}) "
                    "is not a subtype of the list's item type "
                    "(self.item_type() = {self_item_type} "
                    .format(**locals())))

        self._items().append(item)

    cpdef Py_ssize_t count(self, item) except *:
        # TODO: Optimize count by avoiding python call.
        return self._items().count(item)

    cpdef void extend(self, typed_list) except *:
        cdef TypedList typed_list_cy = <TypedList?> typed_list
        cdef tuple self_full_type
        cdef tuple extend_full_type

        self_full_type =  self.full_type()
        extend_full_type = typed_list_cy.full_type()

        if not is_sub_full_type(extend_full_type, self_full_type):
            raise (
                TypeError(
                    "The extending typed list's full type "
                    "(typed_list.full_type() = {extend_full_type})) "
                    "is not a subtype of the extended typed list's full type "
                    "(self.full_type() = {self_full_type}))."
                    .format(**locals())))

        self._items().extend(typed_list_cy._items())

    cpdef Py_ssize_t index(self, item) except *:
        # TODO: Optimize index by avoiding python call.
        return self._items().index(item)

    cpdef void insert(self, Py_ssize_t id, item) except *:
        cdef object self_item_type
        cdef object item_type
        cdef BaseReadableTypedList item_as_typed_list

        self_item_type = self.item_type()

        if not is_instance(item, self_item_type):
            if isinstance(item, BaseReadableTypedList):
                item_as_typed_list = <BaseReadableTypedList?>item
                item_type = item_as_typed_list.full_type()
            else:
                item_type = type(item)

            raise (
                TypeError(
                    "The item (type(item) or? item.full_type() = {item_type}) "
                    "is not a subtype of the list's item type "
                    "(self.item_type() = {self_item_type} "
                    .format(**locals())))

        self._items().insert(id, item)

    cpdef pop(self, Py_ssize_t id = -1):
        return self._items().pop(id)

    cpdef void remove(self, item) except *:
        # TODO: Optimize remove by avoiding python call.
        self._items().remove(item)

    cpdef void reverse(self):
        self._items().reverse()

    cpdef tuple full_type(self):
        return (type(self), self.item_type())

    cpdef item_type(self):
        return self.__item_type

    cpdef list _items(self):
        return self.__items

@cython.warn.undeclared(True)
cdef TypedList new_TypedList(object item_type):
    cdef TypedList typed_list

    typed_list = TypedList.__new__(TypedList)
    init_TypedList(typed_list, item_type)

    return typed_list

@cython.warn.undeclared(True)
cdef void init_TypedList(TypedList typed_list, object item_type) except *:
    if typed_list is None:
        raise TypeError("The typed list (typed_list) cannot be None.")

    if not is_valid_item_type(item_type):
        raise (
            TypeError(
                "The item type (item_type = {item_type}) is not a valid item "
                "type for typed list."
                .format(**locals())))

    typed_list.__items = []
    typed_list.__item_type = item_type


@cython.warn.undeclared(True)
@cython.auto_pickle(True)
cdef class FixedLenTypedList(BaseWritableTypedList):
    def __init__(self, typed_list):
        init_FixedLenTypedList(self, typed_list)

    cpdef shallow_copy(self, copy_obj = None):
        cdef FixedLenTypedList new_list
        cdef TypedList typed_list

        if copy_obj is None:
            new_list = FixedLenTypedList.__new__(FixedLenTypedList)
        else:
            new_list = copy_obj

        typed_list = self.__typed_list
        new_list.__typed_list = typed_list.shallow_copy()

        return new_list

    def __len__(self):
        return len(self._typed_list())

    def __contains__(self, item):
        return item in self._typed_list()

    def __iter__(self):
        return iter(self._typed_list())

    cpdef item(self, Py_ssize_t id):
        cdef TypedList typed_list

        typed_list = self._typed_list()

        return typed_list.item(id)

    cpdef list items_shallow_copy(self):
        cdef TypedList typed_list

        typed_list = self._typed_list()

        return typed_list.items_shallow_copy()

    cpdef typed_list_shallow_copy(self):
        cdef TypedList typed_list

        typed_list = self._typed_list()

        return typed_list.shallow_copy()

    cpdef void set_item(self, Py_ssize_t id, item) except *:
        cdef TypedList typed_list

        typed_list = self._typed_list()

        typed_list.set_item(id, item)

    cpdef void set_items(self, list items) except *:
        cdef Py_ssize_t items_len
        cdef Py_ssize_t self_len
        cdef TypedList typed_list

        typed_list = self._typed_list()

        items_len = len(items)
        self_len = len(self)

        if items_len != self_len:
            raise (
                ValueError (
                    "The length of the items list (len(items) = {items_len}) "
                    "must be equal to the length of the fixed length list "
                    "(len(self) = {self_len})."
                    .format(**locals())))

        typed_list.set_items(items)

    cpdef Py_ssize_t count(self, item) except *:
        cdef TypedList typed_list

        typed_list = self._typed_list()

        return typed_list.count(item)

    cpdef Py_ssize_t index(self, item) except *:
        cdef TypedList typed_list

        typed_list = self._typed_list()

        return typed_list.index(item)

    cpdef void reverse(self):
        cdef TypedList typed_list

        typed_list = self._typed_list()

        typed_list.reverse()

    cpdef tuple full_type(self):
        return (type(self), self.item_type())

    cpdef item_type(self):
        cdef TypedList typed_list

        typed_list = self._typed_list()

        return typed_list.item_type()

    cpdef _typed_list(self):
        return self.__typed_list

@cython.warn.undeclared(True)
cdef FixedLenTypedList new_FixedLenTypedList(TypedList typed_list):
    cdef FixedLenTypedList fixed_len_list

    fixed_len_list = FixedLenTypedList.__new__(FixedLenTypedList)
    init_FixedLenTypedList(fixed_len_list, typed_list)

    return fixed_len_list

@cython.warn.undeclared(True)
cdef void init_FixedLenTypedList(
        FixedLenTypedList fixed_len_list,
        TypedList typed_list
        ) except *:

    if fixed_len_list is None:
        raise (
            TypeError(
                "The fixed length list (fixed_len_list) cannot be None." ))

    if typed_list is None:
        raise TypeError("The typed list (typed_list) cannot be None.")

    fixed_len_list.__typed_list = typed_list

@cython.warn.undeclared(True)
cpdef bint is_valid_item_type(item_type) except *:
    cdef object item_type_tuple

    if isinstance(item_type, tuple):
        item_type_tuple = item_type
        if len(item_type_tuple) == 2:
            if isinstance(item_type_tuple[0], type):
                if issubclass(item_type_tuple[0], BaseReadableTypedList ):
                    return is_valid_item_type(item_type_tuple[1])
                else:
                    return False
            else:
                return False
        else:
            return False
    else:
        return isinstance(item_type, type)

@cython.warn.undeclared(True)
cpdef bint is_instance(item, target_type) except *:
    cdef BaseReadableTypedList item_as_typed_list
    cdef item_type

    if isinstance(item, BaseReadableTypedList):
        item_as_typed_list = <BaseReadableTypedList?> item
        item_type = item.full_type()
        return is_sub_full_type(item_type, target_type)

    else:
        if isinstance(target_type, type):
            return isinstance(item, target_type)
        else:
            return False

@cython.warn.undeclared(True)
cpdef bint is_sub_full_type(full_type, target_full_type) except *:
    cdef tuple full_type_as_tuple
    cdef tuple target_full_type_as_tuple

    if target_full_type is object:
        return True

    if isinstance(full_type, type):
        if isinstance(target_full_type, type):
            return issubclass(full_type, target_full_type)
        else:
            return False
    elif isinstance(full_type, tuple):
        if isinstance(target_full_type, tuple):
            full_type_as_tuple = full_type
            target_full_type_as_tuple = target_full_type
            if (
                    len(full_type_as_tuple) == 2
                    and len(target_full_type_as_tuple) == 2):
                if (
                        isinstance(full_type_as_tuple[0], type)
                        and isinstance(target_full_type_as_tuple[0], type)):
                    if (
                            issubclass(
                                full_type_as_tuple[0],
                                BaseReadableTypedList )
                            and issubclass(
                                target_full_type_as_tuple[0],
                                BaseReadableTypedList )):

                        return (
                            is_sub_full_type(
                                full_type_as_tuple[1],
                                target_full_type_as_tuple[1])
                            and is_sub_full_type(
                                full_type_as_tuple[0],
                                target_full_type_as_tuple[0]))
                    else:
                        return False
                else:
                    return False
            else:
                return False
        else:
            return False
    else:
        return False
