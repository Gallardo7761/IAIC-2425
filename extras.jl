function diff_1_one_digit(c1::Cell, c2::Cell)
    x1,y1,z1 = c1.x, c1.y, c1.z
    x2,y2,z2 = c2.x, c2.y, c2.z

    for d1 in [x1,y1,z1]
        for d2 in [x2,y2,z2]
            if abs(d1-d2) == 1
                return true
            end
        end
    end

    return false
end