!
!  Copyright 2017 SALMON developers
!
!  Licensed under the Apache License, Version 2.0 (the "License");
!  you may not use this file except in compliance with the License.
!  You may obtain a copy of the License at
!
!      http://www.apache.org/licenses/LICENSE-2.0
!
!  Unless required by applicable law or agreed to in writing, software
!  distributed under the License is distributed on an "AS IS" BASIS,
!  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
!  See the License for the specific language governing permissions and
!  limitations under the License.
!
subroutine calcELF
!$ use omp_lib 
use scf_data
use gradient_sub
use new_world_sub
use allocate_mat_sub
implicit none

integer :: iob,ix,iy,iz

real(8) :: elftau(mg_sta(1):mg_end(1),   &
                  mg_sta(2):mg_end(2),   &
                  mg_sta(3):mg_end(3))
real(8) :: mrelftau(mg_sta(1):mg_end(1),   &
                    mg_sta(2):mg_end(2),   &
                    mg_sta(3):mg_end(3))
real(8) :: curden(mg_sta(1):mg_end(1),   &
                  mg_sta(2):mg_end(2),   &
                  mg_sta(3):mg_end(3))
real(8) :: mrcurden(mg_sta(1):mg_end(1),   &
                    mg_sta(2):mg_end(2),   &
                    mg_sta(3):mg_end(3))
real(8) :: gradpsi(3,mg_sta(1):mg_end(1),   &
                     mg_sta(2):mg_end(2),   &
                     mg_sta(3):mg_end(3))
complex(8) :: tzpsi(mg_sta(1):mg_end(1),   &
                    mg_sta(2):mg_end(2),   &
                    mg_sta(3):mg_end(3))
complex(8) :: gradzpsi(3,mg_sta(1):mg_end(1),   &
                       mg_sta(2):mg_end(2),   &
                       mg_sta(3):mg_end(3))
real(8) :: gradrho(3,mg_sta(1):mg_end(1),   &
                     mg_sta(2):mg_end(2),   &
                     mg_sta(3):mg_end(3))
real(8) :: gradrho2(mg_sta(1):mg_end(1),   &
                    mg_sta(2):mg_end(2),   &
                    mg_sta(3):mg_end(3))
real(8) :: elfc(mg_sta(1):mg_end(1),   &
                mg_sta(2):mg_end(2),   &
                mg_sta(3):mg_end(3))
real(8) :: elfcuni(mg_sta(1):mg_end(1),   &
                   mg_sta(2):mg_end(2),   &
                   mg_sta(3):mg_end(3))
real(8) :: rho_half(mg_sta(1):mg_end(1),   &
                    mg_sta(2):mg_end(2),   &
                    mg_sta(3):mg_end(3))

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(801)=MPI_Wtime()

!$OMP parallel do
do iz=mg_sta(3),mg_end(3)
do iy=mg_sta(2),mg_end(2)
do ix=mg_sta(1),mg_end(1)
  rho_half(ix,iy,iz)=rho(ix,iy,iz)/2.d0
end do
end do
end do
mrelftau=0.d0
mrcurden=0.d0

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(802)=MPI_Wtime()
elp3(832)=elp3(832)+elp3(802)-elp3(801)

iwk_size=1
call make_iwksta_iwkend

if(iSCFRT==1)then

  do iob=1,iobnum
    call calc_gradient(psi(:,:,:,iob,1),gradpsi(:,:,:,:))

!$OMP parallel do
    do iz=mg_sta(3),mg_end(3)
    do iy=mg_sta(2),mg_end(2)
    do ix=mg_sta(1),mg_end(1)
      mrelftau(ix,iy,iz)=mrelftau(ix,iy,iz)+abs(gradpsi(1,ix,iy,iz))**2      &
                         +abs(gradpsi(2,ix,iy,iz))**2      &
                         +abs(gradpsi(3,ix,iy,iz))**2
    end do
    end do
    end do
  end do

  call MPI_ALLREDUCE(mrelftau,elftau,      &
       mg_num(1)*mg_num(2)*mg_num(3),      &
       MPI_DOUBLE_PRECISION,MPI_SUM,newworld_comm_grid,IERR)

  call calc_gradient(rho_half(:,:,:),gradrho(:,:,:,:))
  do iz=mg_sta(3),mg_end(3)
  do iy=mg_sta(2),mg_end(2)
  do ix=mg_sta(1),mg_end(1)
    gradrho2(ix,iy,iz)=gradrho(1,ix,iy,iz)**2      &
          +gradrho(2,ix,iy,iz)**2      &
          +gradrho(3,ix,iy,iz)**2
    elfc(ix,iy,iz)=elftau(ix,iy,iz)-gradrho2(ix,iy,iz)/rho_half(ix,iy,iz)/4.d0
  end do
  end do
  end do


else if(iSCFRT==2)then

  do iob=1,iobnum
    if(itt==0)then
      !$OMP parallel do collapse(2)
      do iz=mg_sta(3),mg_end(3)
      do iy=mg_sta(2),mg_end(2)
      do ix=mg_sta(1),mg_end(1)
        tzpsi(ix,iy,iz)=zpsi_in(ix,iy,iz,iob,1)
      end do
      end do
      end do
    else
      if(mod(itt,2)==1)then
      !$OMP parallel do collapse(2)
        do iz=mg_sta(3),mg_end(3)
        do iy=mg_sta(2),mg_end(2)
        do ix=mg_sta(1),mg_end(1)
          tzpsi(ix,iy,iz)=zpsi_out(ix,iy,iz,iob,1)
        end do
        end do
        end do
      else
      !$OMP parallel do collapse(2)
        do iz=mg_sta(3),mg_end(3)
        do iy=mg_sta(2),mg_end(2)
        do ix=mg_sta(1),mg_end(1)
          tzpsi(ix,iy,iz)=zpsi_in(ix,iy,iz,iob,1)
        end do
        end do
        end do
      end if
    end if
    
    call calc_gradient(tzpsi,gradzpsi)

    elp3(807)=MPI_Wtime()

!$OMP parallel do
    do iz=mg_sta(3),mg_end(3)
    do iy=mg_sta(2),mg_end(2)
    do ix=mg_sta(1),mg_end(1)

      mrelftau(ix,iy,iz)=mrelftau(ix,iy,iz)+abs(gradzpsi(1,ix,iy,iz))**2      &
                         +abs(gradzpsi(2,ix,iy,iz))**2      &
                         +abs(gradzpsi(3,ix,iy,iz))**2

      mrcurden(ix,iy,iz)=mrcurden(ix,iy,iz)      &
           +( abs(conjg(tzpsi(ix,iy,iz))*gradzpsi(1,ix,iy,iz)      &
                -tzpsi(ix,iy,iz)*conjg(gradzpsi(1,ix,iy,iz)))**2      &
             +abs(conjg(tzpsi(ix,iy,iz))*gradzpsi(2,ix,iy,iz)      &
                -tzpsi(ix,iy,iz)*conjg(gradzpsi(2,ix,iy,iz)))**2      &
             +abs(conjg(tzpsi(ix,iy,iz))*gradzpsi(3,ix,iy,iz)      &
                -tzpsi(ix,iy,iz)*conjg(gradzpsi(3,ix,iy,iz)))**2 )/4.d0

    end do
    end do
    end do
    
    elp3(808)=MPI_Wtime()
    elp3(838)=elp3(838)+elp3(808)-elp3(807)

  end do

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(809)=MPI_Wtime()
elp3(839)=elp3(839)+elp3(809)-elp3(808)

  call MPI_ALLREDUCE(mrelftau,elftau,      &
     mg_num(1)*mg_num(2)*mg_num(3),      &
     MPI_DOUBLE_PRECISION,MPI_SUM,newworld_comm_grid,IERR)
  call MPI_ALLREDUCE(mrcurden,curden,      &
     mg_num(1)*mg_num(2)*mg_num(3),      &
     MPI_DOUBLE_PRECISION,MPI_SUM,newworld_comm_grid,IERR)

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(810)=MPI_Wtime()
elp3(840)=elp3(840)+elp3(810)-elp3(809)

  call calc_gradient(rho_half(:,:,:),gradrho(:,:,:,:))

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(815)=MPI_Wtime()

  do iz=mg_sta(3),mg_end(3)
  do iy=mg_sta(2),mg_end(2)
  do ix=mg_sta(1),mg_end(1)
    gradrho2(ix,iy,iz)=gradrho(1,ix,iy,iz)**2      &
          +gradrho(2,ix,iy,iz)**2      &
          +gradrho(3,ix,iy,iz)**2
    elfc(ix,iy,iz)=elftau(ix,iy,iz)-gradrho2(ix,iy,iz)/rho_half(ix,iy,iz)/4.d0  &
                                   -curden(ix,iy,iz)/rho_half(ix,iy,iz)
  end do
  end do
  end do

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(816)=MPI_Wtime()
elp3(846)=elp3(846)+elp3(816)-elp3(815)

end if

do iz=mg_sta(3),mg_end(3)
do iy=mg_sta(2),mg_end(2)
do ix=mg_sta(1),mg_end(1)
  elfcuni(ix,iy,iz)=3.d0/5.d0*(6.d0*Pi**2)**(2.d0/3.d0)      &
            *rho_half(ix,iy,iz)**(5.d0/3.d0)
  elf(ix,iy,iz)=1.d0/(1.d0+elfc(ix,iy,iz)**2/elfcuni(ix,iy,iz)**2)
end do
end do
end do

!call MPI_BARRIER(MPI_COMM_WORLD,ierr)
elp3(817)=MPI_Wtime()
elp3(847)=elp3(847)+elp3(817)-elp3(816)

!$OMP parallel do collapse(2)
do iz=lg_sta(3),lg_end(3)
do iy=lg_sta(2),lg_end(2)
do ix=lg_sta(1),lg_end(1)
  matbox_l(ix,iy,iz)=0.d0
end do
end do
end do

!$OMP parallel do collapse(2)
do iz=ng_sta(3),ng_end(3)
do iy=ng_sta(2),ng_end(2)
do ix=ng_sta(1),ng_end(1)
  matbox_l(ix,iy,iz)=elf(ix,iy,iz)
end do
end do
end do

call MPI_Allreduce(matbox_l,elf, &
                   lg_num(1)*lg_num(2)*lg_num(3), &
                   MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)

end subroutine calcELF

