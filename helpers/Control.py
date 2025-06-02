import numpy as np
import matplotlib.pyplot as plt

exec_t = 6 # Tiempo de ejecución (s)
ts = 50e-3 # Tiempo de muestreo (s)
start_t = 1 # Tiempo de inicio de interpolación (s)
stop_t = 4 # Tiempo de fin de interpolación (s)
setpoint = 120 # Referencia al final de la interpolación
stall = 200 # Constante de feedforward
kp = 60 # Ganancia proporcional
ki = 8 # Ganancia integral
kd = 4 # Ganancia derivativa

if start_t >= stop_t or exec_t < stop_t:
    raise Exception("Check time intervals") # Verificar que el tiempo de paro de la interpolación 
# sea mayor al tiempo de inicio y que el tiempo de ejecución también sea mayor al tiempo de paro

num_ciclos = int(exec_t / ts) # Numero de muestreos en tiempo de ejecución
num_ciclos_middle = int((stop_t-start_t)/ts) # Numero de muestreos en la interpolación
num_ciclos_start = int(start_t/ts) # Numero de ciclos en el inicio
num_ciclos_end = int((exec_t-stop_t)/ts) # Numero de ciclos en el final

t_int = np.linspace(0,1,num_ciclos_middle) # Vector de tiempo para interpolación
print("T interpolated vector", t_int)
traj_middle = 1-(1-t_int)**3 # easeOutCirc curva
print("Trajectory middle", traj_middle)

traj_temp = np.concatenate((np.array([0]*num_ciclos_start),traj_middle,np.array([1]*num_ciclos_end))) # Trayectoria completa no escalada
traj = traj_temp*setpoint # Trayectoria completa escalada
t_vector = np.linspace(0,exec_t,num_ciclos) # Vector de tiempo

integral = 0 # Acumulador integral 
previous_error = 0 # Condicion inicial del error
u_stall_temp = np.linspace(stall,0,num_ciclos_middle) # Pendiente negativa de la constante de feedforward durante la interpolacion
u_stall = np.concatenate((np.array([0]*num_ciclos_start),u_stall_temp,np.array([0]*num_ciclos_end)))
# Feedforward completo

position = 0 # Lectura del encoder

for i in range(len(t_vector)): # Ciclo de control
    error = traj[i] - position # Lazo de retroalimentacion
    proportional = error # Parte proporcional
    integral += error*ts # Parte integral
    derivative = (error - previous_error)/ts # Parte derivativa
    previous_error = error # Actualizacion del error para siguiente ciclo

    u = kp*proportional + ki*integral + kd * derivative + u_stall[i] # Ley de control

    if u > 1024:
        u = 1024
    elif u < -1024:
        u = -1024   # Saturacion a 1024

plt.plot(t_vector,traj)
plt.show()
