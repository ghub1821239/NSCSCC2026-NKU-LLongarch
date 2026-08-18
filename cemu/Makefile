SRC_DIR = src
OBJ_DIR = obj

DIRS = $(shell find $(SRC_DIR) -type d)
SRCS = $(shell find $(SRC_DIR) -name '*.cpp')
HEADERS = $(shell find $(SRC_DIR) -name '*.hpp')
OBJS = $(SRCS:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)

CXX = g++
CXXFLAGS = -lpthread -std=c++17 -O3

.PHONY: clean

cemu: obj $(OBJS)
	$(CXX) $(OBJS) $(CXXFLAGS) -o $@

obj:
	mkdir -p $(OBJ_DIR)

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) $(addprefix -I,${DIRS}) -c $< -o $@

# clean:
# 	rm $(OBJS)

# ---- LA32R golden-trace dump ----
LA32R_MAIN = example_main/nscscc_la32r_main.cpp
INCLUDES   = $(addprefix -I,$(DIRS))
.PHONY: cemu_la32r
cemu_la32r: $(LA32R_MAIN) $(HEADERS)
	$(CXX) $(CXXFLAGS) $(INCLUDES) $(LA32R_MAIN) -o $@
clean:
	rm -f $(OBJS) cemu cemu_la32r