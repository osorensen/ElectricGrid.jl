import numpy as np
import matplotlib.pyplot as plt
import scipy
import control
import copy
import networkx as nx
import random




class NodeConstructor():
    """Node Constructor implementation.

    Helper class for creating a grid structure for scaling purposes. The grid can be defined externally via a so-called CM matrix or randomly generated by the class. The given grid structure is then used to create the ODE equation systems. The output of the equation systems is done via the state space representation with the help of the A, B, C and D matrices. The generated grid can be visualized additionally.

    Attributes:
        num_source: Number of sources in the grid (1,)
        num_loads: Number of loads in the grid (1,)
        tot_ele: Total number of objects in the grid (1,)
        parameter: Dict which includes the parameters of the components 
        S2S_p: Probability that a source is connected to a source (1,)
        S2L_p: Probability that a source is connected to a load (1,)
        num_connections: Number of drawn connections between all objects (1,)
        CM: Connection Matrix specifies which objects are linked to each other via which connection (tot_ele, tot_ele)
        generate_CM: Function that generates CM randomly. A connection to the network is guaranteed, so that no subnets can occur.
        get_sys: Function which outputs the system matrices in the statespace representation
        draw_graph: Function which plots a graph based on the CM
    """
    def __init__(self, num_source, num_loads, parameter, S2S_p=0.1, S2L_p=0.8, CM=None):
        """Creates and initialize a nodeconstructor class instance.

        First the parameters are unpacked and then a CM is created, if not passed.

        Args:
            num_source: Number of sources in the grid (1,)
            num_loads: Number of loads in the grid (1,)
            parameter: Dict which includes the parameters of the components
            S2S_p: Probability that a source is connected to a source (1,)
            S2L_p: Probability that a source is connected to a load (1,)
            CM: Connection Matrix specifies which objects are linked to each other via which connection (tot_ele, tot_ele)
        
        """
        self.num_source = num_source
        self.num_loads = num_loads
        self.tot_ele = num_source + num_loads
        self.S2S_p = S2S_p
        self.S2L_p = S2L_p
        self.cntr = 0
        self.num_connections = 0
        
        # unpack parameters
        self.parameter = parameter
        self.R_source = parameter['R_source']
        self.L_source = parameter['L_source']
        self.C_source = parameter['C_source']
        self.R_cabel = parameter['R_cabel']
        self.L_cabel = parameter['L_cabel']
        self.R_load = parameter['R_load']
        
        if isinstance(CM, np.ndarray):
            assert CM.shape[0] == self.tot_ele, "Expect CM to have the same number of elements as tot_ele."
            self.CM = CM
            self.num_connections=np.amax(CM)
        elif CM == None:
            self.generate_CM()
        else:
            raise f"Expect CM to be an np.ndarray or None not {type(CM)}."
    
    def tobe_or_n2b(self, x, p):
        """Sets x based on p to zero or to the value of the counter and increments it."""

        # To count up the connection, cntr is returned.
        # If only one type of cabel is used this is not necessary an can be replaced by 1
        
        if x < p:
            self.cntr += 1  
            return self.cntr
        else:
            x = 0
            return x
    
    def count_up(self):
        """Increment counter"""

        self.cntr += 1
        return self.cntr
    
    def generate_CM(self):
        """Constructs the CM
        
        Returns the constructed CM and the total number of connections.
        """
        
        # counting the connections 
        self.cntr = 0

        # get a upper triangular matrix
        mask = np.tri(self.tot_ele).T
        CM = np.random.rand(self.tot_ele,self.tot_ele) * mask # fill matrix with random entries between [0,1]
        CM = CM - np.eye(CM.shape[0]) * np.diag(CM) # delet diagonal bc no connection with itself
        
        # go throught the matrix
        # -1 bc last entrie is 0 anyway
        for i in range(self.tot_ele-1):

            # start at i, bc we need to check only upper triangle
            for j in range(i, self.tot_ele-1):
                if j >= self.num_source-1: # select propability according to column
                    CM[i, j+1] = self.tobe_or_n2b(CM[i, j+1], self.S2L_p)
                else:
                    CM[i, j+1] = self.tobe_or_n2b(CM[i, j+1], self.S2S_p)
        
        # make sure that no objects disappear or subnets are formed
        for i in range(self.tot_ele):
            entries = list()
            
            # save rows and columns entries
            Col = CM[:i,i]
            Row = CM[i,i+1:]
            
            # get one list in the form of: [column, row]-entries
            entries.append(CM[:i,i].tolist())
            entries.append(CM[i,i+1:].tolist())
            entries = [item for sublist in entries for item in sublist]

            non_zero = np.sum([entries[i] != 0 for i in range(len(entries))]) # number of non_zero entries
            zero = np.sum([entries[i] == 0 for i in range(len(entries))]) # number of zero entries

            val_to_set = min(2, zero) # minimum of connections is 2
            
            if non_zero <= 2: # we need to set values if there are less then 2 entries
                idx_list = list() # create list to store indexes
                idx_row_entries = np.where(0==Col) # Get rows of the entries = 0
                idx_col_entries = np.where(0==Row) # Get col of the entries = 0

                idx_row_entries = idx_row_entries[0].tolist()
                idx_col_entries = idx_col_entries[0].tolist()

                idx_list.append([(j,i) for _,j in enumerate(idx_row_entries)]) 
                idx_list.append([(i,i+j+1) for _,j in enumerate(idx_col_entries)])
                idx_list = [item for sublist in idx_list for item in sublist]
                
                samples = np.array(val_to_set).clip(0, len(idx_list)) 
                idx_rnd = random.sample(range(0,len(idx_list)), samples) # draw samples from the list
                idx_rnd = np.array(idx_rnd) 
                
                for _, ix in enumerate(idx_rnd):
                    # Based on the random sample, select an indize
                    # from the list and write into the corresponding CM cell.
                    CM[idx_list[ix]] = self.count_up() 
            
        CM = CM - CM.T # copy with negative sign to lower triangle
        
        # save CM
        self.CM = CM
        
        # save number of connections
        self.num_connections = self.cntr
        pass
        
    
    def get_A_source(self):
        """Create the A_source entry for a source in the A matrix
        
        Returns:
            A_source: Matrix with values belonging to corresponding source (2, 2)
        """
        # this matrix is always a 2x2 for inverter
        A_source = np.zeros((2,2))
        A_source[0,0] = -self.R_source/self.L_source
        A_source[0,1] = -1/self.L_source
        A_source[1,0] =  1/self.C_source
        return A_source
    
    def get_B_source(self):
        """Create the B_source entry for a source in the B matrix
        
        Return:
            B_source: Matrix with values belonging to corresponding source (2, 1)
        """
        B_source = np.zeros((2,1))
        B_source[0,0] =  1/self.L_source
        return B_source
    
    def get_A_col(self, source_x):
        """Create the A_col entry in the A matrix

        Return:
            A_col: Matrix with the column entries for A (2, num_connections)
        """

        # for this case self.C_source is assumed to be just an int.
        # Later self.C_source could be an array with the diffrent paramters and would be indexed via self.C_source[source_x]
        
        A_col = np.zeros((2, self.num_connections))
        
        CM_row = self.CM[source_x-1]
        
        indizes = list(CM_row[CM_row != 0]) # get entries unequal 0
        signs = np.sign(indizes) # get signs
        indizes_ = indizes*signs # delet signs from indices
        indizes_.astype(dtype=np.int32)
        
        for i, (idx, sign) in enumerate(zip(indizes_, signs)):
            idx = int(idx)
            
            A_col[1,idx-1] = sign * -1/self.C_source
                                        
        return A_col
    
    def get_A_row(self, source_x):
        """Create the A_row entry in the A matrix

        Return:
            A_row: Matrix with the row entries for A (num_connections, 2)
        """

        A_row = np.zeros((2, self.num_connections))
        
        CM_col = self.CM[source_x-1]
        
        indizes = list(CM_col[CM_col != 0]) # get entries unequal 0
        
        signs = np.sign(indizes) # get signs
        indizes_ = indizes*signs # delet signs from indices
        
        for i, (idx, sign) in enumerate(zip(indizes_, signs)):
            idx = int(idx)
            A_row[1,idx-1] = sign *1/self.L_cabel 
        
        return A_row.T
    
    def get_A_transitions(self):
        """Create the A_transitions entry in the A matrix

        Return:
            A_transitions: Matrix with column entries for A (num_connections, num_connections)
        """
        A_transitions = np.zeros((self.num_connections, self.num_connections))
        for i in range(1,self.num_connections+1):
            (row, col) = np.where(self.CM==i)
            (row_idx, col_idx) = (row[0], col[0])
            
            # check if its a S2S connection
            if col_idx < self.num_source: # row_idx < self.num_source and 
                
                A_transitions[i-1,i-1] = -self.R_cabel/self.L_cabel # self.R_cabel[i] and self.L_cabel[i]
                
            # Then it has to be S2L
            else:
                # easy diagonal entry
                A_transitions[i-1,i-1] = -(self.R_cabel + self.R_load)/self.L_cabel # (self.R_cabel[i] + self.R_load[col_idx])/self.L_cabel[i] -> self.R_load[col_idx]? not sure
                
                # search for other connections to this specific load in the colum
                CM_col = self.CM[:,col_idx]
                
                mask = np.logical_and(CM_col > 0, CM_col != i) # i bc we already cover this case
                indizes = list(CM_col[mask])
                
                # cross entries for the other connections to this load
                for j, idx in enumerate(indizes):
                    idx = int(idx)
                    A_transitions[i-1, idx-1] = -self.R_load/self.L_cabel # self.L_cabel[i] if LT is an arry with diffrent values and self.R_load[col_idx]?
        
        return A_transitions
    
    def generate_A(self):
        """Generate the A matrix
        
        The previously constructed matrices are now plugged together in the form:

            [[A_source, A_col],
            [A_row, A_transitions]]

        Returns:
            A: A matrix for state space ((2*num_source+num_connections),(2*num_source+num_connections))
        """
        # get A_source
        A_source = np.zeros((2*self.num_source,2*self.num_source)) # construct matrix of zeros
        A_source_list = [self.get_A_source() for i in range(self.num_source)]
                
        for i, ele in enumerate(A_source_list):
            start = 2*i
            stop = 2*i+2
            A_source[start:stop,start:stop] = ele
        
        # get A_col
        A_col = np.zeros((2*self.num_source, self.num_connections))
        A_col_list = [self.get_A_col(i) for i in range(1,self.num_source+1)] # start at 1 bc Source 1 ...
        
        for i, ele in enumerate(A_col_list):
            start = 2*i
            stop = 2*i+2
            A_col[start:stop,:] = ele
        
        # get A_row
        A_row = np.zeros((self.num_connections, 2*self.num_source))
        A_row_list = [self.get_A_row(i) for i in range(1,self.num_source+1)] # start at 1 bc Source 1 ...
        
        for i, ele in enumerate(A_row_list):
            start = 2*i
            stop = 2*i+2
            A_row[:,start:stop] = ele
            
        A_transitions = self.get_A_transitions()
        
        A = np.block([[A_source, A_col],
                     [A_row, A_transitions]])
        
        return A
    
    def generate_B(self):
        """Generate the B matrix
        
        The previously constructed matrices are now plugged together in the form:

            [[B_source,        0, ...,         0],
             [       0, B_source, ...,         0],
             [       0,        0, ...,         0],
             [       0,        0, ...,  B_source]]

        Returns:
            B: B matrix for state space (2*num_source+num_connections,num_source)

        """
        B = np.zeros((2*self.num_source+self.num_connections,self.num_source))
        
        B_source_list = [self.get_B_source() for i in range(1,self.num_source+1)] # start at 1 bc Source 1 ...
        for i, ele in enumerate(B_source_list):
#             start_c = i
#             stop_c = i+1
            start_r = 2*i
            stop_r = 2*i+2
            B[start_r:stop_r,i:i+1] = ele
        return B
    
    def generate_C(self):
        """Generate the C matrix
        
        Retruns:
            C: Identity matrix (2*num_source+num_connections)
        """
        return np.eye(2*self.num_source+self.num_connections)
    
    def generate_D(self):
        """Generate the D vector
        
        Retruns:
            0: Zero vector (2*num_source+num_connections)
        """
        return 0
    
    def get_sys(self):
        """Returns state space matrices"""

        A = self.generate_A()
        B = self.generate_B()
        C = self.generate_C()
        D = self.generate_D()
        return (A, B, C, D)
    
    def draw_graph(self):
        """Plots a graph according to the CM matrix
        
        Red nodes corresponse to a source.
        Blue nodes corresponse to a load.
        """
        
        edges = []
        color = []
        for i in range(1, self.num_connections+1):
            (row, col) = np.where(self.CM==i)
            (row_idx, col_idx) = (row[0]+1, col[0]+1)
            edges.append((row_idx, col_idx))
            if row_idx <= self.num_source:
                color.append('red')
            else:
                color.append('blue')
        
        G = nx.Graph(edges)
        
        color_map = []

        for node in G:
            if node <= self.num_source:
                color_map.append('red')
            else:
                color_map.append('lightblue')

        nx.draw(G, node_color=color_map, with_labels = True)
        plt.show()
        
        pass